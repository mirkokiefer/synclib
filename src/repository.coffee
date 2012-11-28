
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

# helpers
readOrCreateNewTree = (treeStore) -> (hash, cb) -> if hash then treeStore.read hash, cb else cb null, new Tree()
readOrCreateNewTrees = (trees, treeStore, cb) -> async.map trees, readOrCreateNewTree(treeStore), cb
readCommitTree = (commitStore) -> (hash, cb) -> if not hash then cb null else
  commitStore.read hash, (err, {tree}) -> cb null, tree
readCommitTrees = (hashs, commitStore, cb) -> async.map hashs, readCommitTree(commitStore), cb

# recursive parts of Repository
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
      else cb null

readTreeAtPath = (treeHash, treeStore, path, cb) ->
  treeStore.read treeHash, (err, tree) ->
    if path.length == 0 then cb null, tree
    else
      key = path.pop()
      readTreeAtPath tree.childTrees[key], treeStore, path, cb

read = (treeHash, treeStore, path, cb) ->
  if not treeHash then cb null
  else
    treeStore.read treeHash, (err, tree) ->
      key = path.pop()
      if path.length == 0 then cb null, tree.childData[key]
      else read tree.childTrees[key], treeStore, path, cb

allPaths = (treeHash, treeStore, cb) ->
  treeStore.read treeHash, (err, tree) ->
    paths = (path:[key], value:value for key, value of tree.childData)
    findChildPaths = (paths, [key, childTree], cb) ->
      allPaths childTree, treeStore, (err, childPaths) ->
        res = (path: [key, path...], value:value  for {path, value} in childPaths)
        cb null, paths.concat res
    async.reduce pairs(tree.childTrees), paths, findChildPaths, cb

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
  readOrCreateNewTrees [tree1Hash, tree2Hash], treeStore, (err, [tree1, tree2]) ->
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
  readOrCreateNewTrees [tree1Hash, tree2Hash], treeStore, (err, [tree1, tree2]) ->
    diff = values: [], trees: if tree2Hash then [{hash: tree2Hash, data: tree2}] else []
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
  commitStore.read toCommitHash, (err, toCommit) ->
    diff = commits: [{hash: toCommitHash, data: toCommit}], trees: [], values: []
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
        findIntersectingHashs = (hashObjects) ->
          intersectingHashs = intersection((pluck each, 'hash' for each in hashObjects)...)
          union(hashObjects...).filter (each) -> contains intersectingHashs, each.hash
        diff = mergeDiffs diff,
          trees: findIntersectingHashs (pluck ancestorDiffs, 'trees')
          values: intersection(pluck(ancestorDiffs, 'values')...)
        reduceFun = (diff, ancestor, cb) ->
          mapCommonCommit = (each, cb) -> findCommonCommit ancestor, each, treeStore, cb
          async.map commonCommitHashs, mapCommonCommit, (err, newCommonTreeHashs) ->
            findDelta union(newCommonTreeHashs), ancestor, treeStore, commitStore, (err, ancestorDelta) ->
              cb null, mergeDiffs diff, ancestorDelta
        async.reduce toCommit.ancestors, diff, reduceFun, cb

mergingCommit = (commonTreeHash, tree1Hash, tree2Hash, strategy, treeStore, cb) ->
  conflict = (commonTreeHash != tree1Hash) and (commonTreeHash != tree2Hash)
  if not conflict then (if tree1Hash == commonTreeHash then cb null, tree2Hash else cb null, tree1Hash)
  else
    readOrCreateNewTrees [commonTreeHash, tree1Hash, tree2Hash], treeStore, (err, [commonTree, tree1, tree2]) ->
      newTree = new Tree
      mergeData = ->
        for key in union(keys(tree2.childData), keys(tree1.childData))
          commonData = commonTree.childData[key]; data1 = tree1.childData[key]; data2 = tree2.childData[key];
          conflict = (commonData != data1) and (commonData != data2)
          if conflict
            newTree.childData[key] = strategy key, data1, data2
          else
            newTree.childData[key] = if data1 == commonData then data2 else data1
      mergeChildTrees = (cb) ->
        mergeAtKey = (key, cb) ->
          mergingCommit commonTree.childTrees[key], tree1.childTrees[key], tree2.childTrees[key], strategy, treeStore, (err, newChildTree) ->
            newTree.childTrees[key] = newChildTree
            cb()
        async.forEach union(keys(tree2.childTrees), keys(tree1.childTrees)), mergeAtKey, cb
      mergeData()
      mergeChildTrees ->
        treeStore.write newTree, cb

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
  treeAtPath: (commitHash, path, cb) ->
    obj = this
    path = if path == '' then [] else path.split('/').reverse()
    @_commitStore.read commitHash, (err, {tree}) ->
      readTreeAtPath tree, obj._treeStore, path, cb
  dataAtPath: (commitHash, path, cb) ->
    obj = this
    path = path.split('/').reverse()
    @_commitStore.read commitHash, (err, {tree}) ->
      read tree, obj._treeStore, path, cb
  allPaths: (commitHash, cb) ->
    obj = this
    @_commitStore.read commitHash, (err, {tree}) ->
      allPaths tree, obj._treeStore, (err, paths) ->
        cb null, (path:path.join('/'), value:value for {path, value} in paths)
  commonCommit: (commit1, commit2, cb) -> findCommonCommit commit1, commit2, @_commitStore, cb
  commonCommitWithPaths: (commit1, commit2, cb) -> findCommonCommitWithPaths commit1, commit2, @_commitStore, cb
  diff: (commit1, commit2, cb) ->
    obj = this
    readCommitTrees [commit1, commit2], obj._commitStore, (err, [tree1, tree2]) ->
      findDiffWithPaths tree1, tree2, obj._treeStore, (err, diff) ->
        translatePaths = (array) -> {path: path.join('/'), value} for {path, value} in array
        cb null, trees: translatePaths(diff.trees), values: translatePaths(diff.values)
  delta: ({from, to}, cb) ->
    obj = this
    diff = commits: [], trees: [], values: []
    deltaForEach = (diff, toEach, cb) ->
      async.map from, ((fromEach, cb) -> obj.commonCommit fromEach, toEach, cb), (err, commonCommits) ->
        commonCommits = _.without commonCommits, undefined
        findDelta commonCommits, toEach, obj._treeStore, obj._commitStore, (err, newDelta) ->
          cb null, mergeDiffs diff, newDelta
    async.reduce to, diff, deltaForEach, (err, delta) ->
      serialize = (objects) -> ({hash, data: data.constructor.serialize data} for {hash, data} in objects)
      cb null, commits: serialize(delta.commits), trees: serialize(delta.trees), values: delta.values
  applyDelta: (delta, cb) ->
    obj = this
    async.parallel [
      (cb) -> obj.commitStore.writeAll (pluck delta.commits, 'data'), cb
      (cb) -> obj.treeStore.writeAll (pluck delta.trees, 'data'), cb
    ], cb
  merge: (commit1, commit2, strategy, cb) ->
    obj = this
    if not commit1 then return cb null, commit2
    if not commit2 then return cb null, commit1
    strategy = if strategy then strategy else (path, value1Hash, value2Hash) -> value1Hash
    @commonCommit commit1, commit2, (err, commonCommit) ->
      if commit1 == commonCommit then return cb null, commit2
      else if commit2 == commonCommit then return cb null, commit1
      else
        readCommitTrees [commonCommit, commit1, commit2], obj._commitStore, (err, [commonTree, tree1, tree2]) ->
          mergingCommit commonTree, tree1, tree2, strategy, obj._treeStore, (err, newTree) ->
            obj._commitStore.write (new Commit ancestors: [commit1, commit2], tree: newTree), cb

module.exports = Repository
