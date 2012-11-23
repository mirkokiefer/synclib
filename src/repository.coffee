
async = require 'async'
_ = require 'underscore'
{union, values, keys, intersection, clone, contains, pluck} = _
{objectDiff, objectDiffObject, addKeyPrefix, Queue} = require './utils'
Branch = require './branch'
TreeStore = require './tree-store'
contentAddressable = require('content-addressable').memory
keyValueStore = require('pluggable-store').memory

class Tree
  constructor: ({ancestors, childTrees, childData}={}) ->
    @ancestors = if ancestors then ancestors else []
    @childTrees = if childTrees then childTrees else {}
    @childData = if childData then childData else {}

groupCurrentAndChildTreeData = (data) ->
  currentTreeData = {}
  childTreeData = {}
  for {path, hash} in data
    key = path.pop()
    if path.length == 0 then currentTreeData[key] = hash
    else
      if not childTreeData[key] then childTreeData[key] = []
      childTreeData[key].push {path, hash}
  [currentTreeData, childTreeData]

commit = (treeHash, data, treeStore) ->
  changedTree = false
  currentTree = if treeHash then treeStore.read treeHash else new Tree()
  [currentTreeData, childTreeData] = groupCurrentAndChildTreeData data
  for key, hash of currentTreeData
    if currentTree.childData[key] != hash
      changedTree = true
      if hash then currentTree.childData[key]=hash
      else delete currentTree.childData[key]
  for key, data of childTreeData
    previousTree = currentTree.childTrees[key]
    newChildTree = commit previousTree, data, treeStore
    if newChildTree != previousTree
      changedTree = true
      if newChildTree then currentTree.childTrees[key] = newChildTree
      else delete currentTree.childTrees[key]
  if (_.size(currentTree.childTrees) > 0) or (_.size(currentTree.childData) > 0)
    if changedTree
      if treeHash then currentTree.ancestors = [treeHash]
      treeStore.write currentTree
    else treeHash

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

treeAncestors = (treeHash, treeStore) ->
  tree = treeStore.read(treeHash)
  if tree then tree.ancestors else []

findWalkPath = (tree, visited) ->
  arr = [tree]
  while (tree=visited[tree])
    arr.push tree
  arr

findCommonCommitWithPaths = (tree1Start, tree2Start, treeStore) ->
  if (not tree1Start) or (not tree2Start) then return undefined
  [walker1, walker2] = for each in [tree1Start, tree2Start]
    walker = queue: new Queue, visited: {}    
    walker.queue.push each
    walker.visited[each]=null
    walker
  
  while (tree1=walker1.queue.pop()) or (tree2=walker2.queue.pop())
    for [tree, visited] in [[tree1, walker2.visited], [tree2, walker1.visited]]
      if visited[tree] != undefined
        return tree: tree, tree1Path: findWalkPath(tree, walker1.visited), tree2Path: findWalkPath(tree, walker2.visited)
    for [tree, walker] in [[tree1, walker1], [tree2, walker2]] 
      ancestors = treeAncestors tree, treeStore
      for each in ancestors
        walker.queue.push each
        if not walker.visited[each] then walker.visited[each] = tree
  undefined

findCommonCommit = (tree1, tree2, treeStore) ->
  res = findCommonCommitWithPaths tree1, tree2, treeStore
  if res then res.tree

findDiffWithPaths = (tree1Hash, tree2Hash, treeStore) ->
  if tree1Hash == tree2Hash then return trees: [], data: []
  [tree1, tree2] = for each in [tree1Hash, tree2Hash]
    if each then treeStore.read each else new Tree()
  diff = data: [], trees: [{path:[], hash: if tree2Hash then tree2Hash else null}]
  updatedData = ({path:[key], hash:value} for key, value of tree2.childData when tree1.childData[key] != value)
  deletedData = ({path:[key], hash:null} for key of tree1.childData when tree2.childData[key] == undefined)
  diff.data = union updatedData, deletedData
  mapChildTree = (diff, key) ->
    childDiff = findDiffWithPaths tree1.childTrees[key], tree2.childTrees[key], treeStore
    prependPath = (pathHashs) -> {path: [key, path...], hash: hash} for {path, hash} in pathHashs
    trees: union(diff.trees, prependPath(childDiff.trees)),
    data: union(diff.data, prependPath(childDiff.data))
  union(keys(tree1.childTrees), keys(tree2.childTrees)).reduce mapChildTree, diff

mergeDiffs = (oldDiff, newDiff) -> trees: union(oldDiff.trees, newDiff.trees), data: union(oldDiff.data, newDiff.data)

findDeltaDiff = (tree1Hash, tree2Hash, treeStore) ->
  if tree1Hash == tree2Hash then return trees: [], data: []
  [tree1, tree2] = for each in [tree1Hash, tree2Hash]
    if each then treeStore.read each else new Tree()
  diff = data: [], trees: if tree2Hash then [tree2Hash] else []
  diff.data = (value for key, value of tree2.childData when tree1.childData[key] != value)
  mapChildTree = (diff, key) ->
    childDiff = findDeltaDiff tree1.childTrees[key], tree2.childTrees[key], treeStore
    mergeDiffs diff, childDiff
  union(keys(tree1.childTrees), keys(tree2.childTrees)).reduce mapChildTree, diff

findDelta = (commonTreeHashs, toTreeHash, treeStore) ->
  if contains commonTreeHashs, toTreeHash then return trees: [], data: []
  toTree = treeStore.read toTreeHash
  ancestorDiffs = for ancestor in toTree.ancestors
    findDeltaDiff(ancestor, toTreeHash, treeStore)
  if toTree.ancestors.length == 1
    mergeDiffs ancestorDiffs[0], findDelta(commonTreeHashs, toTree.ancestors[0], treeStore)
  else if toTree.ancestors.length == 0
    findDeltaDiff(null, toTreeHash, treeStore)
  else
    diff = trees: union(pluck(ancestorDiffs, 'trees')...), data: intersection(pluck(ancestorDiffs, 'data')...)
    reduceFun = (diff, ancestor) ->
      newCommonTreeHashs = union(findCommonCommit ancestor, each, treeStore for each in commonTreeHashs)
      mergeDiffs diff, findDelta(newCommonTreeHashs, ancestor, treeStore)
    toTree.ancestors.reduce reduceFun, diff

mergingCommit = (commonTreeHash, tree1Hash, tree2Hash, strategy, treeStore) ->
  conflict = (commonTreeHash != tree1Hash) and (commonTreeHash != tree2Hash)
  if not conflict then (if tree1Hash == commonTreeHash then tree2Hash else tree1Hash)
  else
    [commonTree, tree1, tree2] = for each in [commonTreeHash, tree1Hash, tree2Hash]
      if each then treeStore.read each
      else new Tree()
    ancestors = (each for each in [tree1Hash, tree2Hash] when each)
    newTree = new Tree ancestors: ancestors
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
  constructor: ({@treeStore}={}) ->
    if not @treeStore then @treeStore = contentAddressable()
    @_treeStore = new TreeStore @treeStore
  branch: (treeHash) -> new Branch this, treeHash
  commit: (oldTree, data) ->
    parsedData = (path: path.split('/').reverse(), hash: hash for path, hash of data)
    commit oldTree, parsedData, @_treeStore
  treeAtPath: (tree, path) ->
    path = if path == '' then [] else path.split('/').reverse()
    readTreeAtPath tree, @_treeStore, path    
  dataAtPath: (tree, path) ->
    path = path.split('/').reverse()
    read tree, @_treeStore, path
  allPaths: (treeHash) ->
    path:path.join('/'), value:value for {path, value} in allPaths treeHash, @_treeStore
  commonCommit: (tree1, tree2) -> findCommonCommit tree1, tree2, @_treeStore
  commonCommitWithPaths: (tree1, tree2) -> findCommonCommitWithPaths tree1, tree2, @_treeStore
  diff: (tree1, tree2) ->
    diff = findDiffWithPaths tree1, tree2, @_treeStore
    translatePaths = (array) -> {path: path.join('/'), hash} for {path, hash} in array
    {trees: translatePaths(diff.trees), data: translatePaths(diff.data)}
  deltaHashs: ({from, to}) ->
    diff = trees: [], data: []
    for toEach in to
      commonTrees = (@commonCommit fromEach, toEach for fromEach in from)
      diff = mergeDiffs diff, findDelta(commonTrees, toEach, @_treeStore)
    diff
  deltaData: (delta) ->
    {trees: (@treeStore.read each for each in delta.trees), data: delta.data}
  merge: (tree1, tree2, strategy) ->
    obj = this
    strategy = if strategy then strategy else (path, value1Hash, value2Hash) -> value1Hash
    commonTree = @commonCommit tree1, tree2
    if tree1 == commonTree then tree2
    else if tree2 == commonTree then tree1
    else
      mergingCommit commonTree, tree1, tree2, strategy, @_treeStore

module.exports = Repository
