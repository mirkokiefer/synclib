
async = require 'async'
_ = require 'underscore'
union = _.union
values = _.values
keys = _.keys
intersection = _.intersection
clone = _.clone

Branch = require './branch'

flattenResults = (cb) -> (err, results) -> cb null, _.flatten results

class Tree
  constructor: ({ancestors, childTrees, childData}={}) ->
    @ancestors = if ancestors then ancestors else []
    @childTrees = if childTrees then childTrees else {}
    @childData = if childData then childData else {}

readTree = (store) -> (hash, cb) ->
  if not hash then cb null, undefined
  else store.readTree hash, (err, data) -> cb null, new Tree data

splitCurrentAndChildTreeData = (data) ->
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
  currentTree = if treeHash
    tree = treeStore.read treeHash
    new Tree childData:clone(tree.childData), childTrees:clone(tree.childTrees), ancestors:[treeHash]
  else new Tree()
  [currentTreeData, childTreeData] = splitCurrentAndChildTreeData data
  for key, hash of currentTreeData
    if hash then currentTree.childData[key]=hash
    else delete currentTree.childData[key]
  for key, data of childTreeData
    previousTree = currentTree.childTrees[key]
    newChildTree = commit previousTree, data, treeStore
    if newChildTree then currentTree.childTrees[key] = newChildTree
    else delete currentTree.childTrees[key]
  if (_.size(currentTree.childTrees) > 0) or (_.size(currentTree.childData) > 0)
    treeStore.write currentTree

readTreeAtPath = (treeHash, store, path, cb) ->
  store.readTree treeHash, (err, tree) ->
    if path.length == 0 then cb null, tree
    else
      key = path.pop()
      readTreeAtPath tree.childTrees[key], store, path, cb

read = (treeHash, treeStore, path) ->
  if not treeHash then undefined
  else
    tree = treeStore.read treeHash
    key = path.pop()
    if path.length == 0 then tree.childData[key]
    else read tree.childTrees[key], treeStore, path

treeParents = (treeHash, store, cb) -> readTree(store) treeHash, (err, tree) -> cb(null, tree.ancestors)
treesParents = (store) -> (trees, cb) ->
  async.map trees, ((each, cb) -> treeParents each, store, cb), flattenResults cb

findCommonCommit = (trees1, trees2, store, cb) ->
  if (trees1.current.length == 0) and (trees2.current.length == 0)
    cb null, undefined
    return
  for [trees1, trees2] in [[trees1, trees2], [trees2, trees1]]
    for each in trees1.current when _.contains trees2.visited.concat(trees2.current), each
      cb null, each
      return
  async.map [trees1.current, trees2.current], treesParents(store), (err, [trees1Parents, trees2Parents]) ->
    merge = (oldTrees, newParents) -> current: newParents, visited:oldTrees.visited.concat(oldTrees.current)
    findCommonCommit merge(trees1, trees1Parents), merge(trees2, trees2Parents), store, cb

findDiffWithPaths = (tree1Hash, tree2Hash, store, cb) ->
  if tree1Hash == tree2Hash
    cb null, {trees: {}, data: {}}
    return
  async.map [tree1Hash, tree2Hash], readTree(store), (err, [tree1, tree2]) ->
    tree1 = if tree1 then tree1 else new Tree()
    tree2 = if tree2 then tree2 else new Tree()
    diff = data: {}, trees: {}
    for key, childTree of tree2.childTrees when tree1.childTrees[key] != childTree
      diff.trees[key] = childTree
    for key, data of tree2.childData when tree1.childData[key] != data
      diff.data[key] = data
    for key, childTree of tree1.childTrees when tree2.childTrees[key] == undefined
      diff.trees[key] = null
    for key, data of tree1.childData when tree2.childData[key] == undefined
      diff.data[key] = null
    mapChildTree = (diff, key, cb) ->
      findDiffWithPaths tree1.childTrees[key], tree2.childTrees[key], store, (err, childDiff) ->
        for childKey, childTree of childDiff.trees
          diff.trees[key+'/'+childKey] = childTree
        for childKey, childData of childDiff.data
          diff.data[key+'/'+childKey] = childData
        cb null, diff
    async.reduce _.keys(diff.trees), diff, mapChildTree, cb

findDiff = (tree1Hash, tree2Hash, store, cb) ->
  findDiffWithPaths tree1Hash, tree2Hash, store, (err, res) -> cb null, trees: values(res.trees), data: values(res.data)

findDiffSince = (positions, oldTrees, store, cb) ->
  for each in oldTrees when _.contains positions, each
    positions = _.without positions, each
    oldTrees = _.without oldTrees, each
  if (oldTrees.length == 0) or (positions.length == 0) then cb null, {trees: [], data: []}
  else
    mergeDiff = (diff, cb) -> (err, newDiff) ->
      cb null, trees: union(diff.trees, newDiff.trees), data: union(diff.data, newDiff.data)
    mergeDiffs = (cb) -> (err, newDiffs) ->
      reduceFun = (previous, current) ->
        trees: union(previous.trees, current.trees), data: union(previous.data, current.data)
      cb null, (newDiffs.reduce reduceFun, {trees: [], data: []})
    mapFun = (eachPosition, cb) ->
      treeParents eachPosition, store, (err, ancestors) ->
        if ancestors.length > 0
          collectParentDiff = (eachParent, cb) ->
            findDiff eachParent, eachPosition, store, cb
          async.map ancestors, collectParentDiff, mergeDiffs (err, diff) ->
            findDiffSince ancestors, oldTrees, store, (mergeDiff diff, cb)
        else findDiff null, eachPosition, store, cb
    async.map positions, mapFun, mergeDiffs cb

mergingCommit = (commonTreeHash, tree1Hash, tree2Hash, strategy, store, cb) ->
  conflict = (commonTreeHash != tree1Hash) and (commonTreeHash != tree2Hash)
  if not conflict then cb null, (if tree1Hash == commonTreeHash then tree2Hash else tree1Hash)
  else
    async.map [commonTreeHash, tree1Hash, tree2Hash], readTree(store), (err, [commonTree, tree1, tree2]) ->
      commonTree = if commonTree then commonTree else new Tree()
      tree1 = if tree1 then tree1 else new Tree()
      tree2 = if tree2 then tree2 else new Tree()
      ancestors = (each for each in [tree1Hash, tree2Hash] when each)
      newTree = new Tree ancestors: ancestors
      mergeData = (cb) ->
        each = (key, cb) ->
          commonData = commonTree.childData[key]; data1 = tree1.childData[key]; data2 = tree2.childData[key];
          conflict = (commonData != data1) and (commonData != data2)
          if conflict
            strategy key, data1, data2, (err, res) -> newTree.childData[key] = res; cb()
          else
            newTree.childData[key] = if data1 == commonData then data2 else data1
            cb()
        async.forEach union(keys(tree2.childData), keys(tree1.childData)), each, cb
      mergeChildTrees = (cb) ->
        each = (key, cb) ->
          mergingCommit commonTree.childTrees[key], tree1.childTrees[key], tree2.childTrees[key], strategy, store, (err, res) ->
            newTree.childTrees[key] = res
            cb()
        async.forEach keys(tree2.childTrees), each, cb
      async.parallel [mergeData, mergeChildTrees], () ->
        store.writeTree newTree, cb

class Repository
  constructor: (@treeStore) ->
  branch: (treeHash) -> new Branch this, treeHash
  commit: (oldTree, data) ->
    parsedData = (path: path.split('/').reverse(), hash: hash for path, hash of data)
    commit oldTree, parsedData, @treeStore
  treeAtPath: (tree, path) ->
    path = if path == '' then [] else path.split('/').reverse()
    readTreeAtPath tree, @treeStore, path    
  dataAtPath: (tree, path) ->
    path = path.split('/').reverse()
    read tree, @treeStore, path
  commonCommit: (tree1, tree2) ->
    [trees1, trees2] = ({current: [each], visited: []} for each in [tree1, tree2])
    findCommonCommit trees1, trees2, @treeStore
  diff: (tree1, tree2) -> findDiffWithPaths tree1, tree2, @treeStore
  diffSince: (trees1, trees2) -> findDiffSince trees1, trees2, @treeStore
  merge: (tree1, tree2, strategy, cb) ->
    obj = this
    commonTree = @commonCommit tree1, tree2
    if tree1 == commonTree then cb null, tree2
    else if tree2 == commonTree then cb null, tree1
    else
      mergingCommit commonTree, tree1, tree2, strategy, obj.backend, cb

module.exports = Repository
