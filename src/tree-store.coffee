
_ = require 'underscore'
computeHash = require('./utils').hash
ContentAddressable = require('content-addressable')
memoryStore = require('pluggable-store').server().memory

serialize = (obj) ->
  sort = (arr) -> arr.sort (a, b) -> a[0] > b[0]
  obj.childTrees = sort(_.pairs obj.childTrees)
  obj.childData = sort(_.pairs obj.childData)
  obj.ancestors = obj.ancestors.sort()
  sorted = sort(_.pairs obj)
  JSON.stringify sorted
deserialize = (string) ->
  parsed = _.object JSON.parse(string)
  parsed.childTrees = _.object parsed.childTrees
  parsed.childData = _.object parsed.childData
  parsed

class TreeStore
  constructor: -> @store = new ContentAddressable store: memoryStore()
  write: (tree) ->
    json = serialize tree
    @store.write json
  read: (hash) -> deserialize @store.read hash
  readAll: (hashs) -> @read each for each in hashs
  writeAll: (trees) -> @write each for each in trees



module.exports = TreeStore