
utils = require 'livelyutils'
async = require 'async'
_ = require 'underscore'

class Tree
  constructor: ({parents, childTrees, childData}={}) ->
    @parents = if parents then parents else []
    @childTrees = if childTrees then childTrees else {}
    @childData = if childData then childData else {}

readTree = (backend) -> (hash, cb) ->
  if not hash then cb null, undefined
  else backend.readTree hash, (err, data) -> cb null, new Tree data

commit = (treeHash, backend, data, cb) ->
  readTree(backend) treeHash, (err, tree) ->
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
        commit tree.childTrees[key], backend, childTreeData[key], (err, newChildTree) ->
          tree.childTrees[key] = newChildTree
          cb()
      async.forEach _.keys(childTreeData), eachFun, cb
    commitChildData = (cb) ->
      eachFun = (key, cb) ->
        backend.writeData childData[key], (err, hash) -> 
          tree.childData[key] = hash
          cb()
      async.forEach _.keys(childData), eachFun, cb
    async.parallel [commitChildTrees, commitChildData], (err) ->
      if treeHash then tree.parents.push treeHash
      backend.writeTree tree, cb

read = (treeHash, backend, path, cb) ->
  if not treeHash then cb null, undefined
  else
    readTree(backend) treeHash, (err, tree) ->
      key = path.pop()
      if path.length == 0 then backend.readData tree.childData[key], cb
      else read tree.childTrees[key], backend, path, cb

treeParents = (treeHash, backend, cb) -> readTree(backend) treeHash, (err, tree) -> cb(null, tree.parents)
treesParents = (trees, backend, cb) ->
  reduceFun = (memo, each, cb) -> treeParents each, backend, (err, parents) -> cb(null, memo.concat parents)
  async.reduce trees, [], reduceFun, cb

findCommonCommit = (positions, backend, cb) ->
  findMatchInRestPositions = (firstPosition, restPositions) ->
    visitedFirstPositions = []
    while firstPosition.current.length > 0
      currentPos = firstPosition.current.pop()
      newRestPostions = []
      while restPositions.length > 0
        restPosition = restPositions.pop()
        if (restPosition.visited.indexOf currentPos) > -1
          firstPosition.current.push restPosition.current...
          firstPosition.visited.push restPosition.visited...
        else
          newRestPostions.push restPosition
      if newRestPostions.length == 0
        return [currentPos]
      restPositions = newRestPostions
      visitedFirstPositions.push currentPos
      firstPosition.visited.push currentPos
    [null, visitedFirstPositions, restPositions.reverse()]

  

  if positions.reduce ((memo, each) -> memo and each.current.length == 0), true
    cb null
    return
  [firstPosition, restPositions...] = positions
  newPositions = []
  [match, visitedFirstPositions, restPositions] = findMatchInRestPositions firstPosition, restPositions
  if match then cb null, match
  else
    treesParents visitedFirstPositions, backend, (err, parents) ->
      firstPosition.current = parents
      restPositions.push firstPosition
      findCommonCommit restPositions, backend, cb

findDiff = (tree1Hash, tree2Hash, backend, cb) ->
  if tree1Hash == tree2Hash
    cb null, {trees: {}, data: {}}
    return
  async.map [tree1Hash, tree2Hash], readTree(backend), (err, [tree1, tree2]) ->
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
      findDiff tree1.childTrees[key], tree2.childTrees[key], backend, (err, childDiff) ->
        for childKey, childTree of childDiff.trees
          diff.trees[key+'/'+childKey] = childTree
        for childKey, childData of childDiff.data
          diff.data[key+'/'+childKey] = childData
        cb null, diff
    async.reduce _.keys(diff.trees), diff, mapChildTree, cb

class Store
  constructor: (@backend, @head) ->
  commit: ({data, ref}, cb) ->
    obj = this
    parsedData = for path, value of data
      path: path.split('/').reverse(), data: value
    ref = if ref then ref else @head
    commit ref, @backend, parsedData, (err, newHead) ->
      obj.head = newHead
      cb err, newHead
  read: ({path, ref}, cb) ->
    path = path.split('/').reverse()
    ref = if ref then ref else @head
    read ref, @backend, path, cb
  commonCommit: (trees, cb) ->
    positions = ({current: [each], visited: []} for each in trees.concat this.head)
    findCommonCommit positions, @backend, cb
  diff: (tree1, tree2, cb) -> findDiff tree1, tree2, @backend, cb


module.exports = Store