
utils = require 'livelyutils'
async = require 'async'
_ = require 'underscore'
union = _.union
values = _.values

class Tree
  constructor: ({parents, childTrees, childData}={}) ->
    @parents = if parents then parents else []
    @childTrees = if childTrees then childTrees else {}
    @childData = if childData then childData else {}

readTree = (store) -> (hash, cb) ->
  if not hash then cb null, undefined
  else store.readTree hash, (err, data) -> cb null, new Tree data

commit = (treeHash, store, data, cb) ->
  readTree(store) treeHash, (err, tree) ->
    tree = if tree then tree else new Tree()
    tree.parents = []
    childTreeData = {}
    childData = {}
    for {path, data:value} in data
      key = path.pop()
      if path.length == 0 then childData[key] = value
      else
        if not childTreeData[key] then childTreeData[key] = []
        childTreeData[key].push {path, data:value}
    commitChildTrees = (cb) ->
      eachFun = (key, cb) ->
        commit tree.childTrees[key], store, childTreeData[key], (err, newChildTree) ->
          tree.childTrees[key] = newChildTree
          cb()
      async.forEach _.keys(childTreeData), eachFun, cb
    commitChildData = (cb) ->
      eachFun = (key, cb) ->
        store.writeData childData[key], (err, hash) -> 
          tree.childData[key] = hash
          cb()
      async.forEach _.keys(childData), eachFun, cb
    async.parallel [commitChildTrees, commitChildData], (err) ->
      if treeHash then tree.parents.push treeHash
      store.writeTree tree, cb

read = (treeHash, store, path, cb) ->
  if not treeHash then cb null, undefined
  else
    readTree(store) treeHash, (err, tree) ->
      key = path.pop()
      if path.length == 0 then store.readData tree.childData[key], cb
      else read tree.childTrees[key], store, path, cb

treeParents = (treeHash, store, cb) -> readTree(store) treeHash, (err, tree) -> cb(null, tree.parents)
treesParents = (store) -> (trees, cb) ->
  reduceFun = (memo, each, cb) -> treeParents each, store, (err, parents) -> cb(null, memo.concat parents)
  async.reduce trees, [], reduceFun, cb

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
    merge = (diff, cb) -> (err, newDiff) ->
      cb null, trees: union(diff.trees, newDiff.trees), data: union(diff.data, newDiff.data)
    reduceFun = (diff, eachPosition, cb) ->
      treeParents eachPosition, store, (err, parents) ->
        if parents.length > 0
          reduceFun = (diff, eachParent, cb) ->
            findDiff eachParent, eachPosition, store, merge(diff, cb)
          async.reduce parents, diff, reduceFun, (err, diff) ->
            findDiffSince parents, oldTrees, store, merge(diff, cb)
        else findDiff null, eachPosition, store, merge(diff, cb)         
    async.reduce positions, {trees: [], data: []}, reduceFun, cb

class Branch
  constructor: (@store, @head) ->
  commit: ({data, ref}, cb) ->
    obj = this
    parsedData = for path, value of data
      path: path.split('/').reverse(), data: value
    ref = if ref then ref else @head
    commit ref, @store, parsedData, (err, newHead) ->
      obj.head = newHead
      cb err, newHead
  read: ({path, ref}, cb) ->
    path = path.split('/').reverse()
    ref = if ref then ref else @head
    read ref, @store, path, cb
  commonCommit: (tree, cb) ->
    [trees1, trees2] = ({current: [each], visited: []} for each in [tree, this.head])
    findCommonCommit trees1, trees2, @store, cb
  diff: (tree1, tree2, cb) ->
    if not cb then [tree1, tree2, cb] = [@head, tree1, tree2]
    findDiffWithPaths tree1, tree2, @store, cb
  diffSince: (trees, cb) -> findDiffSince [@head], trees, @store, cb

module.exports = Branch