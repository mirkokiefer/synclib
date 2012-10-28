
async = require 'async'
_ = require 'underscore'

class Branch
  constructor: (@store, @head) ->
  commit: (data, cb) ->
    obj = this
    @store.commit @head, data, (err, newHead) ->
      obj.head = newHead
      cb err, newHead
  treeAtPath: (path, cb) -> @store.treeAtPath @head, path, cb
  dataAtPath: (path, cb) -> @store.dataAtPath @head, path, cb
  commonCommit: (branch, cb) -> @store.commonCommit @head, branch.head, cb
  diff: (branch, cb) -> @store.diff @head, branch.head, cb
  diffSince: (trees, cb) -> @store.diffSince [@head], trees, cb
  merge: ({branch, strategy}, cb) ->
    obj = this
    @store.merge @head, branch.head, strategy, (err, head) ->
      obj.head = head
      cb null, head

module.exports = Branch