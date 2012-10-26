
module.exports =
  Store: require './store'
  backend:
    browser: ->
      Memory: require './backends/memory'
    server: ->
      Memory: require './backends/memory'
      FileSystem: require './backends/filesystem'