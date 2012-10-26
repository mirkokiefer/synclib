
fs = require 'fs'
resolvePath = (require 'path').resolve
exec = require('child_process').exec

removeDir = (dir, cb) -> exec 'rm -r -f ' + dir, cb

treeDir = 'tree'
dataDir = 'data'
getTreePath = (hash) -> treeDir+'/'+hash
getDataPath = (hash) -> dataDir+'/'+hash

class FileSystem
  constructor: (@rootPath) ->
    @_treePath = resolvePath @rootPath, treeDir
    @_dataPath = resolvePath @rootPath, dataDir
    paths = [@rootPath, @_treePath, @_dataPath]
    try
      for each in paths
        if not fs.exists each then fs.mkdirSync each
  writeTree: (path, data, cb) -> @write @treePath(path), data, cb
  readTree: (path, cb) -> @read @treePath(path), cb
  writeData: (path, data, cb) -> @write @dataPath(path), data, cb
  readData: (path, cb) -> @read @dataPath(path), cb
  removeData: (path, cb) -> @remove (@dataPath path), cb
  write: (path, data, cb) -> fs.writeFile path, data, 'utf8', cb
  read: (path, cb) -> fs.readFile path, 'utf8', cb
  remove: (path, cb) -> fs.unlink path, cb
  treePath: (path) -> resolvePath @_treePath, path + '.txt'
  dataPath: (path) -> resolvePath @_dataPath, path + '.txt'
  delete: (cb) -> removeDir @rootPath, cb

module.exports = FileSystem