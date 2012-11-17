
async = require 'async'
_ = require 'underscore'
EventEmitter = require('eventemitter2').EventEmitter2

trees = (treesOrBranches) -> tree each for each in treesOrBranches
tree = (treeOrBranch) -> if treeOrBranch.constructor == Branch then treeOrBranch.head else treeOrBranch

class Branch extends EventEmitter
  constructor: (@repo, @head) ->
  commit: (data) ->
    @head = @repo.commit @head, data
    @emit 'postCommit', @head
    @head
  treeAtPath: (path) -> @repo.treeAtPath @head, path
  dataAtPath: (path) -> @repo.dataAtPath @head, path
  allPaths: -> @repo.allPaths @head
  commonCommit: (ref) -> @repo.commonCommit @head, tree ref
  diff: (ref) -> @repo.diff @head, tree(ref)
  deltaHashs: ({from, to}={}) ->
    head = if @head then [@head] else []
    [from, to] = if from then [trees(from), head] else
      if to then [head, trees(to)]
      else [[], head]
    @repo.deltaHashs from: from, to: to
  merge: ({ref, strategy}) ->
    obj = this
    @head = @repo.merge @head, tree(ref), strategy

module.exports = Branch