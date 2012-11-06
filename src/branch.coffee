
async = require 'async'
_ = require 'underscore'

tree = (treeOrBranch) -> if treeOrBranch.constructor == Branch then treeOrBranch.head else treeOrBranch

class Branch
  constructor: (@repo, @head) ->
  commit: (data) -> @head = @repo.commit @head, data
  treeAtPath: (path, cb) -> @repo.treeAtPath @head, path, cb
  dataAtPath: (path) -> @repo.dataAtPath @head, path
  commonCommit: (ref) -> @repo.commonCommit @head, tree ref
  diff: (ref) -> @repo.diff @head, tree(ref)
  patchHashs: ({from, to}) ->
    [from, to] = if (not from) and (not to) then [null, @head]
    else if from then [tree(from), @head] else [@head, tree(to)]
    @repo.patchHashs from: from, to: to
  merge: ({ref, strategy}, cb) ->
    obj = this
    @repo.merge @head, tree(ref), strategy, (err, head) ->
      obj.head = head
      cb null, head

module.exports = Branch