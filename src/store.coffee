
_ = require 'underscore'
computeHash = require('./utils').hash

class Store
  constructor: (@backend, {@serialize, @deserialize}) ->
  write: (obj, cb) ->
    json = @serialize obj
    @backend.write json, cb
  read: (hash, cb) ->
    obj = this
    @backend.read hash, (err, json) ->
      if json then cb null, obj.deserialize json else cb err, undefined

module.exports = Store