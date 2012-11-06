
async = require 'async'
_ = require 'underscore'

class Branch
  constructor: (@repo, @head) ->
  commit: (data) -> @head = @repo.commit @head, data
  treeAtPath: (path, cb) -> @repo.treeAtPath @head, path, cb
  dataAtPath: (path) -> @repo.dataAtPath @head, path
  commonCommit: (branch) -> @repo.commonCommit @head, branch.head
  diff: (branch) -> @repo.diff @head, branch.head
  patchHashs: ({from, to}) ->
    to = if to != undefined then to else @head
    from = if from != undefined then from else @head
    @repo.patchHashs from: from, to: to
  patch: ({from, to}) ->
    to = if to != undefined then to else @head
    from = if from != undefined then from else @head
    @repo.patch from: from, to: to
  merge: ({branch, strategy}, cb) ->
    obj = this
    @repo.merge @head, branch.head, strategy, (err, head) ->
      obj.head = head
      cb null, head

module.exports = Branch