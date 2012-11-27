
async = require 'async'
_ = require 'underscore'
{union, values, keys, intersection, clone, contains, pluck} = _
{objectDiff, objectDiffObject, addKeyPrefix, Queue} = require './utils'
Branch = require './branch'
Store = require './store'
contentAddressable = require('content-addressable').memory
keyValueStore = require('pluggable-store').memory

class Tree
  constructor: ({childTrees, childData}={}) ->
    @childTrees = if childTrees then childTrees else {}
    @childData = if childData then childData else {}

Tree.serialize = (obj) ->
  sort = (arr) -> arr.sort (a, b) -> a[0] > b[0]
  childTrees = sort(_.pairs obj.childTrees)
  childData = sort(_.pairs obj.childData)
  JSON.stringify [childTrees, childData]
Tree.deserialize = (string) ->
  [childTrees, childData] = JSON.parse(string)
  new Tree childTrees: _.object(childTrees), childData: _.object(childData)

class Commit
  constructor: ({ancestors, @tree, info}={}) ->
    @ancestors = if ancestors then ancestors else []
    @info = if info then info else []

Commit.serialize = (obj) ->
  JSON.stringify [obj.ancestors.sort(), obj.tree, obj.info]
Commit.deserialize = (string) ->
  [ancestors, tree, info] = JSON.parse string
  new Commit ancestors: ancestors, tree: tree, info: info

groupCurrentAndChildTreeData = (data) ->
  currentTreeData = {}; childTreeData = {}
  for {path, value} in data
    key = path.pop()
    if path.length == 0 then currentTreeData[key] = value
    else
      if not childTreeData[key] then childTreeData[key] = []
      childTreeData[key].push {path, value}
  [currentTreeData, childTreeData]

commit = (treeHash, data, treeStore) ->
  if data.length == 0 then return treeHash
  currentTree = if treeHash then treeStore.read treeHash else new Tree()
  [currentTreeData, childTreeData] = groupCurrentAndChildTreeData data
  for key, value of currentTreeData
    if currentTree.childData[key] != value
      if value then currentTree.childData[key] = value
      else delete currentTree.childData[key]
  for key, data of childTreeData
    previousTree = currentTree.childTrees[key]
    newChildTree = commit previousTree, data, treeStore
    if newChildTree != previousTree
      if newChildTree then currentTree.childTrees[key] = newChildTree
      else delete currentTree.childTrees[key]
  if (_.size(currentTree.childTrees) > 0) or (_.size(currentTree.childData) > 0)
    treeStore.write currentTree

readTreeAtPath = (treeHash, treeStore, path) ->
  tree = treeStore.read treeHash
  if path.length == 0 then tree
  else
    key = path.pop()
    readTreeAtPath tree.childTrees[key], treeStore, path

read = (treeHash, treeStore, path) ->
  if not treeHash then undefined
  else
    tree = treeStore.read treeHash
    key = path.pop()
    if path.length == 0 then tree.childData[key]
    else read tree.childTrees[key], treeStore, path

allPaths = (treeHash, treeStore) ->
  tree = treeStore.read treeHash
  paths = []
  for key, childTree of tree.childTrees
    childPaths = allPaths childTree, treeStore
    res = (path: [key, path...], value:value  for {path, value} in childPaths)
    paths = paths.concat res
  paths.concat (path:[key], value:value for key, value of tree.childData)

commitAncestors = (commitHash, commitStore) ->
  commitObj = commitStore.read(commitHash)
  if commitObj then commitObj.ancestors else []

findWalkPath = (tree, visited) ->
  arr = [tree]
  while (tree=visited[tree])
    arr.push tree
  arr

findCommonCommitWithPaths = (commit1Start, commit2Start, commitStore) ->
  if (not commit1Start) or (not commit2Start) then return undefined
  [walker1, walker2] = for each in [commit1Start, commit2Start]
    walker = queue: new Queue, visited: {}    
    walker.queue.push each
    walker.visited[each]=null
    walker
  while (commit1=walker1.queue.pop()) or (commit2=walker2.queue.pop())
    for [commitHash, visited] in [[commit1, walker2.visited], [commit2, walker1.visited]]
      if visited[commitHash] != undefined
        return commit: commitHash, commit1Path: findWalkPath(commitHash, walker1.visited), commit2Path: findWalkPath(commitHash, walker2.visited)
    for [commitHash, walker] in [[commit1, walker1], [commit2, walker2]] 
      ancestors = commitAncestors commitHash, commitStore
      for each in ancestors
        walker.queue.push each
        if not walker.visited[each] then walker.visited[each] = commitHash
  undefined

findCommonCommit = (commit1, commit2, commitStore) ->
  res = findCommonCommitWithPaths commit1, commit2, commitStore
  if res then res.commit

findDiffWithPaths = (tree1Hash, tree2Hash, treeStore) ->
  if tree1Hash == tree2Hash then return trees: [], values: []
  [tree1, tree2] = for each in [tree1Hash, tree2Hash]
    if each then treeStore.read each else new Tree()
  diff = values: [], trees: [{path:[], value: if tree2Hash then tree2Hash else null}]
  updatedData = ({path:[key], value:value} for key, value of tree2.childData when tree1.childData[key] != value)
  deletedData = ({path:[key], value:null} for key of tree1.childData when tree2.childData[key] == undefined)
  diff.values = union updatedData, deletedData
  mapChildTree = (diff, key) ->
    childDiff = findDiffWithPaths tree1.childTrees[key], tree2.childTrees[key], treeStore
    prependPath = (pathHashs) -> {path: [key, path...], value: value} for {path, value} in pathHashs
    trees: union(diff.trees, prependPath(childDiff.trees)),
    values: union(diff.values, prependPath(childDiff.values))
  union(keys(tree1.childTrees), keys(tree2.childTrees)).reduce mapChildTree, diff

findDeltaDiff = (tree1Hash, tree2Hash, treeStore) ->
  if tree1Hash == tree2Hash then return trees: [], values: []
  [tree1, tree2] = for each in [tree1Hash, tree2Hash]
    if each then treeStore.read each else new Tree()
  diff = values: [], trees: if tree2Hash then [tree2Hash] else []
  diff.values = (value for key, value of tree2.childData when tree1.childData[key] != value)
  mapChildTree = (diff, key) ->
    childDiff = findDeltaDiff tree1.childTrees[key], tree2.childTrees[key], treeStore
    trees: union(diff.trees, childDiff.trees), values: union(diff.values, childDiff.values)
  union(keys(tree1.childTrees), keys(tree2.childTrees)).reduce mapChildTree, diff

mergeDiffs = (oldDiff, newDiff) ->
  if not newDiff.commits then newDiff.commits = []
  commits: union(oldDiff.commits, newDiff.commits),
  trees: union(oldDiff.trees, newDiff.trees),
  values: union(oldDiff.values, newDiff.values)

findDelta = (commonCommitHashs, toCommitHash, treeStore, commitStore) ->
  if contains commonCommitHashs, toCommitHash then return commits: [], trees: [], values: []
  diff = commits: [toCommitHash], trees: [], values: []
  toCommit = commitStore.read toCommitHash
  ancestorDiffs = for ancestor in toCommit.ancestors
    findDeltaDiff(commitStore.read(ancestor).tree, toCommit.tree, treeStore)
  if toCommit.ancestors.length == 1
    diff = mergeDiffs diff, ancestorDiffs[0]
    mergeDiffs diff, findDelta(commonCommitHashs, toCommit.ancestors[0], treeStore, commitStore)
  else if toCommit.ancestors.length == 0
    mergeDiffs diff, findDeltaDiff(null, toCommit.tree, treeStore)
  else
    diff = mergeDiffs diff,
      trees: intersection(pluck(ancestorDiffs, 'trees')...),
      values: intersection(pluck(ancestorDiffs, 'values')...)
    reduceFun = (diff, ancestor) ->
      newCommonTreeHashs = union(findCommonCommit ancestor, each, treeStore for each in commonCommitHashs)
      mergeDiffs diff, findDelta(newCommonTreeHashs, ancestor, treeStore, commitStore)
    toCommit.ancestors.reduce reduceFun, diff

mergingCommit = (commonTreeHash, tree1Hash, tree2Hash, strategy, treeStore) ->
  conflict = (commonTreeHash != tree1Hash) and (commonTreeHash != tree2Hash)
  if not conflict then (if tree1Hash == commonTreeHash then tree2Hash else tree1Hash)
  else
    [commonTree, tree1, tree2] = for each in [commonTreeHash, tree1Hash, tree2Hash]
      if each then treeStore.read each
      else new Tree()
    newTree = new Tree
    mergeData = ->
      for key in union(keys(tree2.childData), keys(tree1.childData))
        commonData = commonTree.childData[key]; data1 = tree1.childData[key]; data2 = tree2.childData[key];
        conflict = (commonData != data1) and (commonData != data2)
        if conflict
          newTree.childData[key] = strategy key, data1, data2
        else
          newTree.childData[key] = if data1 == commonData then data2 else data1
    mergeChildTrees = ->
      for key in union keys(tree2.childTrees), keys(tree1.childTrees)
        newTree.childTrees[key] = mergingCommit commonTree.childTrees[key], tree1.childTrees[key], tree2.childTrees[key], strategy, treeStore
    mergeData()
    mergeChildTrees()
    treeStore.write newTree

class Repository
  constructor: ({@treeStore, @commitStore}={}) ->
    if not @treeStore then @treeStore = contentAddressable()
    if not @commitStore then @commitStore = contentAddressable()
    @_treeStore = new Store @treeStore, Tree
    @_commitStore = new Store @commitStore, Commit
  branch: (treeHash) -> new Branch this, treeHash
  commit: (oldCommitHash, data) ->
    oldTree = if oldCommitHash then @_commitStore.read(oldCommitHash).tree
    parsedData = (path: path.split('/').reverse(), value: value for path, value of data)
    newTree = commit oldTree, parsedData, @_treeStore
    if newTree == oldTree then return oldCommitHash
    else
      ancestors = if oldCommitHash then [oldCommitHash] else []
      newCommit = new Commit ancestors: ancestors, tree: newTree
      @_commitStore.write newCommit
  treeAtPath: (commitHash, path) ->
    path = if path == '' then [] else path.split('/').reverse()
    {tree} = @_commitStore.read commitHash
    readTreeAtPath tree, @_treeStore, path    
  dataAtPath: (commitHash, path) ->
    path = path.split('/').reverse()
    {tree} = @_commitStore.read commitHash
    read tree, @_treeStore, path
  allPaths: (commitHash) ->
    {tree} = @_commitStore.read commitHash
    path:path.join('/'), value:value for {path, value} in allPaths tree, @_treeStore
  commonCommit: (commit1, commit2) -> findCommonCommit commit1, commit2, @_commitStore
  commonCommitWithPaths: (commit1, commit2) -> findCommonCommitWithPaths commit1, commit2, @_commitStore
  diff: (commit1, commit2) ->
    [tree1, tree2] = for each in [commit1, commit2]
      if each then @_commitStore.read(each).tree
    diff = findDiffWithPaths tree1, tree2, @_treeStore
    translatePaths = (array) -> {path: path.join('/'), value} for {path, value} in array
    {trees: translatePaths(diff.trees), values: translatePaths(diff.values)}
  deltaHashs: ({from, to}) ->
    diff = commits: [], trees: [], values: []
    for toEach in to
      commonCommits = (@commonCommit fromEach, toEach for fromEach in from)
      diff = mergeDiffs diff, findDelta(commonCommits, toEach, @_treeStore, @_commitStore)
    diff
  deltaData: (delta) ->
    commits: (@commitStore.read each for each in delta.commits)
    trees: (@treeStore.read each for each in delta.trees)
    values: delta.values
  merge: (commit1, commit2, strategy) ->
    obj = this
    strategy = if strategy then strategy else (path, value1Hash, value2Hash) -> value1Hash
    commonCommit = @commonCommit commit1, commit2
    if commit1 == commonCommit then commit2
    else if commit2 == commonCommit then commit1
    else
      [commonTree, tree1, tree2] = for each in [commonCommit, commit1, commit2]
        if each then @_commitStore.read(each).tree
      newTree = mergingCommit commonTree, tree1, tree2, strategy, @_treeStore
      @_commitStore.write new Commit ancestors: [commit1, commit2], tree: newTree

module.exports = Repository
