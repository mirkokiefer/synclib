
utils = require 'livelyutils'
async = require 'async'
_ = require 'underscore'

class Tree
  constructor: (@parents=[], @childTrees={}, @childData={}) ->

readTree = (hash, backend, cb) ->
  if not hash then cb null, undefined
  else backend.readTree hash, cb

commit = (treeHash, backend, data, cb) ->
  readTree treeHash, backend, (err, tree) ->
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
    readTree treeHash, backend, (err, tree) ->
      key = path.pop()
      if path.length == 0 then backend.readData tree.childData[key], cb
      else read tree.childTrees[key], backend, path, cb

findParents = (trees, backend, cb) ->
  reduceFun = (memo, each, cb) ->
    backend.readTree each, (err, tree) ->
      cb(null, memo.concat tree.parents)
  async.reduce trees, [], reduceFun, cb

findMatch = (firstPosition, restPositions) ->
  visitedFirstPositions = []
  while firstPosition.current.length > 0
    currentPos = firstPosition.current.pop()
    newRestPostions = []
    matchCount = 0
    while restPositions.length > 0
      restPosition = restPositions.pop()
      if (restPosition.visited.indexOf currentPos) > -1
        firstPosition.current.push restPosition.current...
        firstPosition.visited.push restPosition.visited...
        matchCount++
      else
        newRestPostions.push restPosition
    if matchCount >= newRestPostions.length
      return [currentPos]
    restPositions = newRestPostions
    visitedFirstPositions.push currentPos
    firstPosition.visited.push currentPos
  [null, visitedFirstPositions, restPositions]

commonCommit = (positions, cb) ->
  if positions.reduce ((memo, each) -> memo and each.current.length == 0), true
    cb null
    return
  [firstPosition, restPositions...] = positions
  newPositions = []
  [match, visitedFirstPositions, restPositions] = findMatch firstPosition, restPositions
  if match then cb null, match
  else
    findParents visitedFirstPositions, firstPosition.backend, (err, parents) ->
      firstPosition.current = parents
      restPositions.push firstPosition
      commonCommit restPositions, cb

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
  commonCommit: (stores, cb) ->
    positions = ({current: [each.head], visited: [], backend: each.backend} for each in stores.concat this)
    commonCommit positions, cb

module.exports = Store