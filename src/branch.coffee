
async = require 'async'
_ = require 'underscore'

class Branch
  constructor: (@store, @head) ->
  commit: (data) -> @head = @store.commit @head, data
  treeAtPath: (path, cb) -> @store.treeAtPath @head, path, cb
  dataAtPath: (path) -> @store.dataAtPath @head, path
  commonCommit: (branch) -> @store.commonCommit @head, branch.head
  diff: (branch, cb) -> @store.diff @head, branch.head, cb
  diffSince: (trees, cb) -> @store.diffSince [@head], trees, cb
  merge: ({branch, strategy}, cb) ->
    obj = this
    @store.merge @head, branch.head, strategy, (err, head) ->
      obj.head = head
      cb null, head

module.exports = Branch