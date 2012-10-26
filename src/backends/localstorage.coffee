Memory = require './memory'

class LocalStorage extends Memory
  constructor: -> @data = localStorage

module.exports = LocalStorage