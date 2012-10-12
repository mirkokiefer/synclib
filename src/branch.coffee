
utils = require 'livelyutils'
async = require 'async'
_ = require 'underscore'
union = _.union
values = _.values
keys = _.keys
intersection = _.intersection
clone = _.clone

class Tree
  constructor: ({parents, childTrees, childData}={}) ->
    @parents = if parents then parents else []
    @childTrees = if childTrees then childTrees else {}
    @childData = if childData then childData else {}

readTree = (store) -> (hash, cb) ->
  if not hash then cb null, undefined
  else store.readTree hash, (err, data) -> cb null, new Tree data

commit = (treeHash, data, store, cb) ->
  map = (each, cb) -> store.writeData each[1], (err, hash) -> cb null, path: each[0].split('/').reverse(), hash: hash
  async.map _.pairs(data), map, (err, storedData) ->
    commitWithStoredData treeHash, storedData, store, cb

commitWithStoredData = (treeHash, data, store, cb) ->
  readTree(store) treeHash, (err, tree) ->
    newTree = if tree then new Tree childData:clone(tree.childData), childTrees:clone(tree.childTrees), parents:[treeHash]
    else new Tree()
    childTreeData = {}
    for {path, hash} in data
      key = path.pop()
      if path.length == 0 then newTree.childData[key] = hash
      else
        if not childTreeData[key] then childTreeData[key] = []
        childTreeData[key].push {path, hash}
    commitEachChildTree = (key, cb) ->
      affectedTree = if tree then tree.childTrees[key]
      commitWithStoredData affectedTree, childTreeData[key], store, (err, newChildTree) ->
        newTree.childTrees[key] = newChildTree
        cb()
    async.forEach keys(childTreeData), commitEachChildTree, (err) ->
      store.writeTree newTree, cb

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

mergingCommit = (commonTreeHash, tree1Hash, tree2Hash, strategy, store, cb) ->
  conflict = (commonTreeHash != tree1Hash) and (commonTreeHash != tree2Hash)
  if not conflict then cb null, (if tree1Hash == commonTreeHash then tree2Hash else tree1Hash)
  else
    async.map [commonTreeHash, tree1Hash, tree2Hash], readTree(store), (err, [commonTree, tree1, tree2]) ->
      commonTree = if commonTree then commonTree else new Tree()
      tree1 = if tree1 then tree1 else new Tree()
      tree2 = if tree2 then tree2 else new Tree()
      parents = (each for each in [tree1Hash, tree2Hash] when each)
      newTree = new Tree parents: parents
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

merge = (branch1, branch2, strategy, store, cb) ->
  branch1.commonCommit branch2.head, (err, commonTree) ->
    if branch1.head == commonTree then cb null, branch2.head
    else if branch2.head == commonTree then cb null, branch1.head
    else
      mergingCommit commonTree, branch1.head, branch2.head, strategy, store, cb

class Branch
  constructor: (@store, @head) ->
  commit: ({data, ref}, cb) ->
    obj = this
    tree = if ref then ref else @head
    commit tree, data, @store, (err, newHead) ->
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
  merge: ({branch, strategy}, cb) ->
    merge this, branch, strategy, @store, cb

module.exports = Branch