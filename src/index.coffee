
module.exports =
  Repository: require './repository'
  TreeStore: require './tree-store'
  backend:
    browser: ->
      Memory: require './backends/memory'
      LocalStorage: require './backends/localstorage'
    server: ->
      Memory: require './backends/memory'
      FileSystem: require './backends/filesystem'