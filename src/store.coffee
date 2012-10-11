
fs = require 'fs'
resolvePath = (require 'path').resolve
exec = require('child_process').exec
hash = require('./utils').hash
_ = require 'underscore'

removeDir = (dir, cb) -> exec 'rm -r -f ' + dir, cb

treeDir = 'tree'
dataDir = 'data'
getTreePath = (hash) -> treeDir+'/'+hash
getDataPath = (hash) -> dataDir+'/'+hash
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

class GenericStore
  writeTree: (tree, cb) ->
    json = serialize tree
    treeHash = hash json
    @write getTreePath(treeHash), json, (err) -> cb null, treeHash
  readTree: (hash, cb) -> @read getTreePath(hash), (err, data) -> cb err, deserialize data
  writeData: (data, cb) ->
    json = JSON.stringify data
    dataHash = hash json
    @write getDataPath(dataHash), data, (err) -> cb null, dataHash
  readData: (hash, cb) -> @read getDataPath(hash), cb

class FileStore extends GenericStore
  constructor: (@rootPath) ->
    paths = [@rootPath, (@resolveDir treeDir), (@resolveDir dataDir)]
    try
      for each in paths
        if not fs.exists each then fs.mkdirSync each
  write: (path, data, cb) -> fs.writeFile (@resolveFile path), data, 'utf8', cb
  read: (path, cb) -> fs.readFile (@resolveFile path), 'utf8', cb
  remove: (path, cb) -> fs.unlink (@resolveFile path), cb
  resolveFile: (path) -> resolvePath @rootPath, path + '.txt'
  resolveDir: (path) -> resolvePath @rootPath, path
  delete: (cb) -> removeDir @rootPath, cb

class MemoryStore extends GenericStore
  constructor: () -> @data = {}
  write: (path, data, cb) -> @data[path] = data; cb null
  read: (path, cb) -> cb null, @data[path]
  remove: (path, cb) -> delete @data[path]; cb null

module.exports =
  FileStore: FileStore
  MemoryStore: MemoryStore