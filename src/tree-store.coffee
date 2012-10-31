
_ = require 'underscore'
computeHash = require('./utils').hash

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

class TrackingStore
  _data: {}
  write: (tree) ->
    json = serialize tree
    treeHash = computeHash json
    @_data[treeHash] = json
    treeHash
  read: (hash) -> deserialize @_data[hash]
  readAll: (hashs) -> @read each for each in hashs
  writeAll: (trees) -> @write each for each in trees

module.exports = TrackingStore