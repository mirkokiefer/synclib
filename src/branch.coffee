
async = require 'async'
_ = require 'underscore'

class Branch
  constructor: (@repo, @head) ->
  commit: (data) -> @head = @repo.commit @head, data
  treeAtPath: (path, cb) -> @repo.treeAtPath @head, path, cb
  dataAtPath: (path) -> @repo.dataAtPath @head, path
  commonCommit: (branch) -> @repo.commonCommit @head, branch.head
  diff: (branch) -> @repo.diff @head, branch.head
  patchHashsSince: (trees) -> @repo.patchHashsSince [@head], trees
  merge: ({branch, strategy}, cb) ->
    obj = this
    @repo.merge @head, branch.head, strategy, (err, head) ->
      obj.head = head
      cb null, head

module.exports = Branch