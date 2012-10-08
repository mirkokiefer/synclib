crypto = require 'crypto'

hash = (data) ->
  shasum = crypto.createHash 'sha1'
  shasum.update data
  shasum.digest 'hex'

module.exports =
  hash: hash