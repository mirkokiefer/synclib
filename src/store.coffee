
utils = require 'livelyutils'
async = require 'async'
_ = require 'underscore'

class Tree
  constructor: (@parent=null, @childTrees={}, @childData={}) ->

readTree = (hash, backend, cb) ->
  if not hash then cb null, undefined
  else backend.readTree hash, cb

commit = (treeHash, backend, data, cb) ->
  readTree treeHash, backend, (err, tree) ->
    tree = if tree then tree else new Tree()
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
      tree.parent = treeHash
      backend.writeTree tree, cb

read = (treeHash, backend, path, cb) ->
  if not treeHash then cb null, undefined
  else
    readTree treeHash, backend, (err, tree) ->
      key = path.pop()
      if path.length == 0 then backend.readData tree.childData[key], cb
      else read tree.childTrees[key], backend, path, cb

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

module.exports = Store