
async = require 'async'
_ = require 'underscore'

class Branch
  constructor: (@store, @head) ->
  commit: (data, cb) ->
    obj = this
    @store.commit @head, data, (err, newHead) ->
      obj.head = newHead
      cb err, newHead
  read: ({path, ref}, cb) ->
    ref = if ref then ref else @head
    @store.read ref, path, cb
  commonCommit: (tree, cb) -> @store.commonCommit @head, tree, cb
  diff: (tree, cb) -> @store.diff @head, tree, cb
  diffSince: (trees, cb) -> @store.diffSince [@head], trees, cb
  merge: ({branch, strategy}, cb) ->
    obj = this
    @store.merge @head, branch.head, strategy, (err, head) ->
      obj.head = head
      cb null, head

module.exports = Branch