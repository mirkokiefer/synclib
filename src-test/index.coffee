
assert = require 'assert'
{Repository, TreeStore} = require '../lib/index'
async = require 'async'
_ = require 'underscore'

repo = new Repository new TreeStore
[testBranchA, testBranchB, testBranchC, testBranchD] = (repo.branch() for each in [1,2,3,4])

testData = (branch, data) ->
  for path, value of data
    assert.equal branch.dataAtPath(path), value

readDataHashs = (hashs, cb) -> async.map hashs, ((each, cb) -> repo.dataAtPathData each, cb), cb
readParents = (treeHash, cb) ->
  repo.dataAtPathTree treeHash, (err, tree) ->
    if tree.ancestors.length == 0
      cb null, treeHash
    else
      async.map tree.ancestors, readParents, (err, res) ->
        cb null, [treeHash, res]
dataA = [
  {'a': "hash1", 'b/c': "hash2", 'b/d': "hash3"}
  {'a': "hash4", 'b/c': "hash5", 'b/e': "hash6", 'b/f/g': "hash7"}
  {'b/e': "hash8"}
]
dataAHashes = [
  '9a3b879755108b450eddf5f035fdc149838f4bec'
  'd19c7dccb948ed962794de79d002525e9b0c9f7f'
  'bdd6e36bdec4c962cbbd21085cd77d85125693db'
]

dataB = [
  {'b/h': "hash9"}
  {'c/a': "hash10"}
  {'a': "hash11", 'u': "hash12"}
  {'b/c': "hash13", 'b/e': "hash14", 'b/f/a': "hash15"}
]
dataC = [dataB[0], dataB[1]]
commitB = {data: dataB, ref: dataAHashes[1], branch: testBranchB}
commitC = {data: dataC, branch: testBranchC}

describe 'branch', () ->
  describe 'commit', () ->
    it 'should commit and read objects', () ->
      head = testBranchA.commit dataA[0]
      assert.equal head, dataAHashes[0]
      testData testBranchA, dataA[0]
    it 'should create a child commit', () ->
      head = testBranchA.commit dataA[1]
      testData testBranchA, dataA[1]
      d = testBranchA.dataAtPath 'b/d'
      assert.equal d, dataA[0]['b/d']
    it 'should read from a previous commit', () ->
      head1 = testBranchA.head
      head2 = testBranchA.commit dataA[2]
      eHead1 = repo.dataAtPath head1, 'b/e'
      assert.equal eHead1, dataA[1]['b/e']
      eHead2 = repo.dataAtPath head2, 'b/e'
      assert.equal eHead2, dataA[2]['b/e']
      eHead2 = testBranchA.dataAtPath 'b/e'
      assert.equal eHead2, dataA[2]['b/e']
    it 'should populate more test branches', () ->
      commitData = ({branch, data, ref}) ->
        branch.head = ref
        branch.commit each for each in data
      commitData each for each in [commitB, commitC]
  describe 'commonCommit', () ->
    # should maybe output the path as well
    it 'should find a common commit', ->
      res = testBranchA.commonCommit testBranchB
      assert.equal res, dataAHashes[1]
    it 'should not find a common commit', ->
      res = testBranchA.commonCommit testBranchC
      assert.equal res, undefined
  ###describe 'diff', () ->
    it 'should find the diff between two trees', (done) ->
      repo.diff dataAHashes[0], dataAHashes[1], (err, diff) ->
        assert.equal _.keys(diff.data).length, _.keys(dataA[1]).length
        for key, data of diff.data
          assert.equal data, hash JSON.stringify(dataA[1][key])
        assert.equal _.keys(diff.trees).length, 2
        assert.equal diff.trees['b'], '87620caa4c53d422ad3a491c511b700e1cd741c8'
        assert.equal diff.trees['b/f'], '4d42003953369bfb8978ba0902311b2cac7d4680'
        done()
    it 'should find the diff between null and a tree', (done) ->
      repo.diff null, dataAHashes[0], (err, diff) ->
        for key, data of diff.data
          assert.equal data, hash JSON.stringify(dataA[0][key])
        done()
    it 'should find the diff between the current head and another tree', (done) ->
      testBranchA.diff testBranchB, (err, diff) ->
        assert.ok diff
        done()
  describe 'diffSince', () ->
    it 'should find the diff between trees in the past and the current head', (done) ->
      testBranchA.diffSince [dataAHashes[0]], (err, diff) ->
        realData = _.union(_.values(dataA[1]), _.values(dataA[2]))
        realDataHashs = (hash JSON.stringify(each) for each in realData)
        assert.equal _.intersection(diff.data, realDataHashs).length, realData.length
        done()
    it 'should find the diff between a tree in the past that doesnt exist and the current head', (done) ->
      testBranchA.diffSince [null], (err, diff) ->
        realDataHashs = (hash JSON.stringify(each) for each in _.values(dataA[0]))
        assert.equal _.intersection(diff.data, realDataHashs).length, realDataHashs.length
        done()
  describe 'merge', () ->
    it 'should merge two branches', (done) ->
      strategy = (path, value1Hash, value2Hash, cb) -> cb null, value2Hash
      oldHead = testBranchA.head
      testBranchA.merge branch: testBranchB, strategy: strategy, (err, head) ->
        repo.diff oldHead, head, (err, res) ->
          for each in dataB
            for key, value of each
              assert.ok (res.data[key] == hash JSON.stringify value) or (res.data[key] == undefined)
          done()
  describe 'commit deletes', () ->
    it 'should delete data', (done) ->
      data = {'b/c': null, 'b/f/a': null, 'b/f/g': null, 'a': 1}
      testBranchB.commit data, (err, head) ->
        testData testBranchB, data, done
  describe 'treeAtPath', () ->
    it 'should read the root tree', (done) ->
      testBranchA.treeAtPath '', (err, tree) ->
        assert.ok tree.childData
        done()

