
_ = require 'underscore'
computeHash = require('./utils').hash

class Store
  constructor: (@backend, {@serialize, @deserialize}) ->
  write: (obj) ->
    json = @serialize obj
    @backend.write json
  read: (hash) ->
    json = @backend.read hash
    if json then @deserialize json else undefined
  readAll: (hashs) -> @read each for each in hashs
  writeAll: (trees) -> @write each for each in trees

module.exports = Store