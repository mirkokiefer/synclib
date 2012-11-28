{union} = require 'underscore'

# diffing keys based on object1
objectDiff = (object1, object2) ->
    updatedPaths = (key for key, value of object2 when object1[key] != value)
    deletedPaths = (key for key, value of object1 when object2[key] == undefined)
    union updatedPaths, deletedPaths

# diffing key-values as an object
objectDiffObject = (object1, object2) ->
  diffObj = {}
  (diffObj[key]=object2[key] for key in objectDiff object1, object2)
  diffObj

addKeyPrefix = (object, prefix) ->
  for key, value of object
    delete object[key]
    object[prefix+key] = value

class Queue
  constructor: -> @data = []
  push: (value) -> @data.push value
  pop: -> @data.shift()
  length: -> @data.length

module.exports =
  objectDiff: objectDiff
  objectDiffObject: objectDiffObject
  addKeyPrefix: addKeyPrefix
  Queue: Queue