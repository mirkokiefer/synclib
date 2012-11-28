
async = require 'async'
_ = require 'underscore'
EventEmitter = require('eventemitter2').EventEmitter2

normalizeAll = (commitsOrBranches) -> normalize each for each in commitsOrBranches
normalize = (commitOrBranch) -> if commitOrBranch.constructor == Branch then commitOrBranch.head else commitOrBranch
normalizeDeltaParams = (from, to, head) ->
  head = if head then [head] else []
  if from then {from: normalizeAll(from), to: head} else
    if to then {from: head, to: normalizeAll(to)}
    else {from: [], to: head}
class Branch extends EventEmitter
  constructor: (@repo, @head) ->
  commit: (data, cb) ->
    obj = this
    @repo.commit @head, data, (err, head) ->
      obj.head = head
      obj.emit 'postCommit', @head
      cb null, head
  treeAtPath: (path, cb) -> @repo.treeAtPath @head, path, cb
  dataAtPath: (path, cb) -> @repo.dataAtPath @head, path, cb
  allPaths: (cb) -> @repo.allPaths @head, cb
  commonCommit: (ref, cb) -> @repo.commonCommit @head, normalize(ref), cb
  commonCommitWithPaths: (ref, cb) -> @repo.commonCommitWithPaths @head, normalize(ref), cb
  diff: (ref, cb) -> @repo.diff @head, normalize(ref), cb
  delta: ({from, to}={}, cb) ->
    @repo.delta (normalizeDeltaParams from, to, @head), cb
  merge: ({ref, strategy}, cb) ->
    obj = this
    @repo.merge @head, normalize(ref), strategy, (err, head) ->
      obj.head = head
      cb null, head

module.exports = Branch