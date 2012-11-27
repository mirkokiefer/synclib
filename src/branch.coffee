
async = require 'async'
_ = require 'underscore'
EventEmitter = require('eventemitter2').EventEmitter2

normalizeAll = (commitsOrBranches) -> normalize each for each in commitsOrBranches
normalize = (commitOrBranch) -> if commitOrBranch.constructor == Branch then commitOrBranch.head else commitOrBranch

class Branch extends EventEmitter
  constructor: (@repo, @head) ->
  commit: (data) ->
    @head = @repo.commit @head, data
    @emit 'postCommit', @head
    @head
  treeAtPath: (path) -> @repo.treeAtPath @head, path
  dataAtPath: (path) -> @repo.dataAtPath @head, path
  allPaths: -> @repo.allPaths @head
  commonCommit: (ref) -> @repo.commonCommit @head, normalize ref
  commonCommitWithPaths: (ref) -> @repo.commonCommitWithPaths @head, normalize ref
  diff: (ref) -> @repo.diff @head, normalize(ref)
  deltaHashs: ({from, to}={}) ->
    head = if @head then [@head] else []
    [from, to] = if from then [normalizeAll(from), head] else
      if to then [head, normalizeAll(to)]
      else [[], head]
    @repo.deltaHashs from: from, to: to
  merge: ({ref, strategy}) ->
    obj = this
    @head = @repo.merge @head, normalize(ref), strategy

module.exports = Branch