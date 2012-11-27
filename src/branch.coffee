
async = require 'async'
_ = require 'underscore'
EventEmitter = require('eventemitter2').EventEmitter2

normalizeAll = (commitsOrBranches) -> normalize each for each in commitsOrBranches
normalize = (commitOrBranch) -> if commitOrBranch.constructor == Branch then commitOrBranch.head else commitOrBranch

class Branch extends EventEmitter
  constructor: (@repo, @head) ->
  commit: (data, cb) ->
    obj = this
    @repo.commit @head, data, (err, head) ->
      obj.head = head
      obj.emit 'postCommit', @head
      cb null, head
  treeAtPath: (path) -> @repo.treeAtPath @head, path
  dataAtPath: (path, cb) -> @repo.dataAtPath @head, path, cb
  allPaths: -> @repo.allPaths @head
  commonCommit: (ref, cb) -> @repo.commonCommit @head, normalize(ref), cb
  commonCommitWithPaths: (ref, cb) -> @repo.commonCommitWithPaths @head, normalize(ref), cb
  diff: (ref, cb) -> @repo.diff @head, normalize(ref), cb
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