computeHash = require('./utils').hash

class BackendWrapper
  constructor: (@backend) ->
  write: (data, cb) ->
    json = JSON.stringify data
    dataHash = computeHash json
    @backend.writeData (dataHash), data, (err) -> cb null, dataHash
  read: (hash, cb) -> @backend.readData hash, cb

module.exports = BackendWrapper