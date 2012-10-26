
class Memory
  constructor: () -> @data = {}
  writeTree: (path, data, cb) -> @write path, data, cb
  readTree: (path, cb) -> @read path, cb
  writeData: (path, data, cb) -> @write path, data, cb
  readData: (path, cb) -> @read path, cb
  write: (path, data, cb) -> @data[path] = data; cb null
  read: (path, cb) -> cb null, @data[path]
  remove: (path, cb) -> delete @data[path]; cb null

module.exports = Memory