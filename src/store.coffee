
hash = require('./utils').hash
_ = require 'underscore'

serialize = (obj) ->
  sort = (arr) -> arr.sort (a, b) -> a[0] > b[0]
  obj.childTrees = sort(_.pairs obj.childTrees)
  obj.childData = sort(_.pairs obj.childData)
  obj.parents = obj.parents.sort()
  sorted = sort(_.pairs obj)
  JSON.stringify sorted
deserialize = (string) ->
  parsed = _.object JSON.parse(string)
  parsed.childTrees = _.object parsed.childTrees
  parsed.childData = _.object parsed.childData
  parsed

class Store
  constructor: (@backend) ->
  writeTree: (tree, cb) ->
    json = serialize tree
    treeHash = hash json
    @backend.writeTree treeHash, json, (err) -> cb null, treeHash
  readTree: (hash, cb) -> @backend.readTree hash, (err, data) -> cb err, deserialize data
  writeData: (data, cb) ->
    json = JSON.stringify data
    dataHash = hash json
    @backend.writeData (dataHash), data, (err) -> cb null, dataHash
  readData: (hash, cb) -> @backend.readData hash, cb

module.exports = Store