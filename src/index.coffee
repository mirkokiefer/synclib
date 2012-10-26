
module.exports =
  Store: require './store'
  backend:
    browser: ->
      Memory: require './backends/memory'
      LocalStorage: require './backends/localstorage'
    server: ->
      Memory: require './backends/memory'
      FileSystem: require './backends/filesystem'