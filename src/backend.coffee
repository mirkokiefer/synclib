
fs = require 'fs'
resolvePath = (require 'path').resolve
crypto = require 'crypto'

hash = (data) ->
  shasum = crypto.createHash 'sha1'
  shasum.update data
  shasum.digest 'hex'

treeDir = 'tree'
dataDir = 'data'
getTreePath = (hash) -> treeDir+'/'+hash
getDataPath = (hash) -> dataDir+'/'+hash

class GenericStore
  writeTree: (tree, cb) ->
    json = JSON.stringify tree
    treeHash = hash json
    @write getTreePath(treeHash), json, (err) -> cb null, treeHash
  readTree: (hash, cb) -> @read getTreePath(hash), (err, data) -> cb err, JSON.parse data
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

class MemoryStore extends GenericStore
  constructor: () -> @data = {}
  write: (path, data, cb) -> @data[path] = data; cb null
  read: (path, cb) -> cb null, @data[path]
  remove: (path, cb) -> delete @data[path]; cb null

module.exports =
  FileStore: FileStore
  MemoryStore: MemoryStore