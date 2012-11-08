
async = require 'async'
_ = require 'underscore'
EventEmitter = require('eventemitter2').EventEmitter2

tree = (treeOrBranch) -> if treeOrBranch.constructor == Branch then treeOrBranch.head else treeOrBranch

class Branch extends EventEmitter
  constructor: (@repo, @head) ->
  commit: (data) ->
    @head = @repo.commit @head, data
    @emit 'postCommit', @head
    @head
  treeAtPath: (path, cb) -> @repo.treeAtPath @head, path, cb
  dataAtPath: (path) -> @repo.dataAtPath @head, path
  commonCommit: (ref) -> @repo.commonCommit @head, tree ref
  diff: (ref) -> @repo.diff @head, tree(ref)
  deltaHashs: ({from, to}={}) ->
    [from, to] = if from then [tree(from), @head] else
      if to
        if to.constructor == Array then [@head, tree(each) for each in to]
        else [@head, tree(to)]
      else [null, @head]
    @repo.deltaHashs from: from, to: to
  merge: ({ref, strategy}) ->
    obj = this
    @head = @repo.merge @head, tree(ref), strategy

module.exports = Branch