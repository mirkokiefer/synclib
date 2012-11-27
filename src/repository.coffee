
async = require 'async'
_ = require 'underscore'
{union, values, keys, intersection, clone, contains, pluck, pairs} = _
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

commit = (treeHash, data, treeStore, cb) ->
  if data.length == 0 then return cb null, treeHash
  treeStore.read treeHash, (err, currentTree) ->
    if not currentTree then currentTree = new Tree()
    [currentTreeData, childTreeData] = groupCurrentAndChildTreeData data
    for key, value of currentTreeData
      if currentTree.childData[key] != value
        if value then currentTree.childData[key] = value
        else delete currentTree.childData[key]
    forEachChildTree = ([key, data], cb) ->
      previousTree = currentTree.childTrees[key]
      commit previousTree, data, treeStore, (err, newChildTree) ->
        if newChildTree != previousTree
          if newChildTree then currentTree.childTrees[key] = newChildTree
          else delete currentTree.childTrees[key]
        cb()
    async.forEach pairs(childTreeData), forEachChildTree, ->
      if (_.size(currentTree.childTrees) > 0) or (_.size(currentTree.childData) > 0)
        treeStore.write currentTree, cb

readTreeAtPath = (treeHash, treeStore, path) ->
  tree = treeStore.read treeHash
  if path.length == 0 then tree
  else
    key = path.pop()
    readTreeAtPath tree.childTrees[key], treeStore, path

read = (treeHash, treeStore, path, cb) ->
  if not treeHash then undefined
  else
    treeStore.read treeHash, (err, tree) ->
      key = path.pop()
      if path.length == 0 then cb null, tree.childData[key]
      else read tree.childTrees[key], treeStore, path, cb

allPaths = (treeHash, treeStore) ->
  tree = treeStore.read treeHash
  paths = []
  for key, childTree of tree.childTrees
    childPaths = allPaths childTree, treeStore
    res = (path: [key, path...], value:value  for {path, value} in childPaths)
    paths = paths.concat res
  paths.concat (path:[key], value:value for key, value of tree.childData)

commitAncestors = (commitHash, commitStore, cb) ->
  commitStore.read commitHash, (err, commitObj) ->
    if commitObj then cb null, commitObj.ancestors else cb null, []

findWalkPath = (tree, visited) ->
  arr = [tree]
  while (tree=visited[tree])
    arr.push tree
  arr

findCommonCommitWithPaths = (commit1Start, commit2Start, commitStore, cb) ->
  if (not commit1Start) or (not commit2Start) then return undefined
  [walker1, walker2] = for each in [commit1Start, commit2Start]
    walker = queue: new Queue, visited: {}    
    walker.queue.push each
    walker.visited[each]=null
    walker
  result = null
  walkOneLevel = (cb) ->
    commit1 = walker1.queue.pop(); commit2 = walker2.queue.pop()
    for [commitHash, visited] in [[commit1, walker2.visited], [commit2, walker1.visited]]
      if visited[commitHash] != undefined
        result = commit: commitHash, commit1Path: findWalkPath(commitHash, walker1.visited), commit2Path: findWalkPath(commitHash, walker2.visited)
        return cb null
    pushAncestors = ([commitHash, walker], cb) ->
      commitAncestors commitHash, commitStore, (err, ancestors) ->
        for each in ancestors
          walker.queue.push each
          if not walker.visited[each] then walker.visited[each] = commitHash
        cb()
    async.forEach [[commit1, walker1], [commit2, walker2]], pushAncestors, cb
  condition = -> (result == null) and ((walker1.queue.length() > 0) or (walker2.queue.length() > 0))
  async.whilst condition, walkOneLevel, ->
    cb null, result

findCommonCommit = (commit1, commit2, commitStore, cb) ->
  findCommonCommitWithPaths commit1, commit2, commitStore, (err, res) ->
    if res then cb null, res.commit else cb null

findDiffWithPaths = (tree1Hash, tree2Hash, treeStore, cb) ->
  if tree1Hash == tree2Hash then return cb null, trees: [], values: []
  readOrCreateNewTree = (hash, cb) -> if hash then treeStore.read hash, cb else cb null, new Tree()
  async.map [tree1Hash, tree2Hash], readOrCreateNewTree, (err, [tree1, tree2]) ->
    diff = values: [], trees: [{path:[], value: if tree2Hash then tree2Hash else null}]
    updatedData = ({path:[key], value:value} for key, value of tree2.childData when tree1.childData[key] != value)
    deletedData = ({path:[key], value:null} for key of tree1.childData when tree2.childData[key] == undefined)
    diff.values = union updatedData, deletedData
    mapChildTree = (diff, key, cb) ->
      findDiffWithPaths tree1.childTrees[key], tree2.childTrees[key], treeStore, (err, childDiff) ->
        prependPath = (pathHashs) -> {path: [key, path...], value: value} for {path, value} in pathHashs
        cb null,
          trees: union(diff.trees, prependPath(childDiff.trees)),
          values: union(diff.values, prependPath(childDiff.values))
    async.reduce union(keys(tree1.childTrees), keys(tree2.childTrees)), diff, mapChildTree, cb

findDeltaDiff = (tree1Hash, tree2Hash, treeStore, cb) ->
  if tree1Hash == tree2Hash then return cb null, trees: [], values: []
  readOrCreateNewTree = (hash, cb) -> if hash then treeStore.read hash, cb else cb null, new Tree()
  async.map [tree1Hash, tree2Hash], readOrCreateNewTree, (err, [tree1, tree2]) ->
    diff = values: [], trees: if tree2Hash then [tree2Hash] else []
    diff.values = (value for key, value of tree2.childData when tree1.childData[key] != value)
    mapChildTree = (diff, key, cb) ->
      findDeltaDiff tree1.childTrees[key], tree2.childTrees[key], treeStore, (err, childDiff) ->
        cb null, trees: union(diff.trees, childDiff.trees), values: union(diff.values, childDiff.values)
    async.reduce union(keys(tree1.childTrees), keys(tree2.childTrees)), diff, mapChildTree, cb

mergeDiffs = (oldDiff, newDiff) ->
  if not newDiff.commits then newDiff.commits = []
  commits: union(oldDiff.commits, newDiff.commits),
  trees: union(oldDiff.trees, newDiff.trees),
  values: union(oldDiff.values, newDiff.values)

findDelta = (commonCommitHashs, toCommitHash, treeStore, commitStore, cb) ->
  if contains commonCommitHashs, toCommitHash then return cb null, commits: [], trees: [], values: []
  diff = commits: [toCommitHash], trees: [], values: []
  commitStore.read toCommitHash, (err, toCommit) ->
    mapAncestorDiffs = (ancestor, cb) ->
      commitStore.read ancestor, (err, {tree}) ->
        findDeltaDiff tree, toCommit.tree, treeStore, cb
    async.map toCommit.ancestors, mapAncestorDiffs, (err, ancestorDiffs) ->
      if toCommit.ancestors.length == 1
        diff = mergeDiffs diff, ancestorDiffs[0]
        findDelta commonCommitHashs, toCommit.ancestors[0], treeStore, commitStore, (err, ancestorDelta) ->
          cb null, mergeDiffs diff, ancestorDelta
      else if toCommit.ancestors.length == 0
        findDeltaDiff null, toCommit.tree, treeStore, (err, deltaDiff) ->
          cb null, mergeDiffs diff, deltaDiff
      else
        diff = mergeDiffs diff,
          trees: intersection(pluck(ancestorDiffs, 'trees')...),
          values: intersection(pluck(ancestorDiffs, 'values')...)
        reduceFun = (diff, ancestor, cb) ->
          mapCommonCommit = (each, cb) -> findCommonCommit ancestor, each, treeStore, cb
          async.map commonCommitHashs, mapCommonCommit, (err, newCommonTreeHashs) ->
            findDelta union(newCommonTreeHashs), ancestor, treeStore, commitStore, (err, ancestorDelta) ->
              cb null, mergeDiffs diff, ancestorDelta
        async.reduce toCommit.ancestors, diff, reduceFun, cb

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
  commit: (oldCommitHash, data, cb) ->
    obj = this
    @_commitStore.read oldCommitHash, (err, oldCommit) ->
      oldTree = if oldCommit then oldCommit.tree
      parsedData = (path: path.split('/').reverse(), value: value for path, value of data)
      commit oldTree, parsedData, obj._treeStore, (err, newTree) ->
        if newTree == oldTree then cb null, oldCommitHash
        else
          ancestors = if oldCommitHash then [oldCommitHash] else []
          newCommit = new Commit ancestors: ancestors, tree: newTree
          obj._commitStore.write newCommit, cb
  treeAtPath: (commitHash, path) ->
    path = if path == '' then [] else path.split('/').reverse()
    {tree} = @_commitStore.read commitHash
    readTreeAtPath tree, @_treeStore, path    
  dataAtPath: (commitHash, path, cb) ->
    obj = this
    path = path.split('/').reverse()
    @_commitStore.read commitHash, (err, {tree}) ->
      read tree, obj._treeStore, path, cb
  allPaths: (commitHash) ->
    {tree} = @_commitStore.read commitHash
    path:path.join('/'), value:value for {path, value} in allPaths tree, @_treeStore
  commonCommit: (commit1, commit2, cb) -> findCommonCommit commit1, commit2, @_commitStore, cb
  commonCommitWithPaths: (commit1, commit2, cb) -> findCommonCommitWithPaths commit1, commit2, @_commitStore, cb
  diff: (commit1, commit2, cb) ->
    obj = this
    readCommitTree = (each, cb) ->
      if each
        obj._commitStore.read each, (err, commitObj) -> cb null, commitObj.tree
      else cb null
    async.map [commit1, commit2], readCommitTree, (err, [tree1, tree2]) ->
      findDiffWithPaths tree1, tree2, obj._treeStore, (err, diff) ->
        translatePaths = (array) -> {path: path.join('/'), value} for {path, value} in array
        cb null, trees: translatePaths(diff.trees), values: translatePaths(diff.values)
  deltaHashs: ({from, to}, cb) ->
    obj = this
    diff = commits: [], trees: [], values: []
    deltaForEach = (diff, toEach, cb) ->
      async.map from, ((fromEach, cb) -> obj.commonCommit fromEach, toEach, cb), (err, commonCommits) ->
        commonCommits = _.without commonCommits, undefined
        findDelta commonCommits, toEach, obj._treeStore, obj._commitStore, (err, newDelta) ->
          cb null, mergeDiffs diff, newDelta
    async.reduce to, diff, deltaForEach, cb
  deltaData: (delta, cb) ->
    obj = this
    commits = (cb) -> async.map delta.commits, ((each, cb) -> obj.commitStore.read each, cb), cb
    trees = (cb) -> async.map delta.trees, ((each, cb) -> obj.treeStore.read each, cb), cb
    async.parallel [commits, trees], (err, [commitsRes, treesRes]) ->
      cb null, commits: commitsRes, trees: treesRes, values: delta.values
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
