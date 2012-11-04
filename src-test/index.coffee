
assert = require 'assert'
{Repository, memoryStore} = require '../lib/index'
async = require 'async'
_ = require 'underscore'

store = memoryStore()
repo = new Repository store
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
  describe 'diff', () ->
    it 'should find the diff between two trees', ->
      diff = repo.diff dataAHashes[0], dataAHashes[1]
      assert.equal _.keys(diff.data).length, _.keys(dataA[1]).length
      for key, data of diff.data
        assert.equal data, dataA[1][key]
      assert.equal _.keys(diff.trees).length, 2
      assert.equal diff.trees['b'], '60d7ae8d0d8ad666cb5155fbe015408b3055dd5b'
      assert.equal diff.trees['b/f'], 'becb16e3c51e87c59dc8746ee084279dcc976c19'
    it 'should find the diff between null and a tree', ->
      diff = repo.diff null, dataAHashes[0]
      for key, data of diff.data
        assert.equal data, dataA[0][key]
    it 'should find the diff between the current head and another tree', ->
      diff = testBranchA.diff testBranchB
      assert.ok diff
  describe 'patchHashsSince', () ->
    it 'should find the diff between trees in the past and the current head', () ->
      diff = testBranchA.patchHashsSince [dataAHashes[0]]
      realData = _.union(_.values(dataA[1]), _.values(dataA[2]))
      assert.equal _.intersection(diff.data, realData).length, realData.length
    it 'should find the diff between a tree in the past that doesnt exist and the current head', () ->
      diff = testBranchA.patchHashsSince [null]
      realDataHashs = _.values(dataA[0])
      assert.equal _.intersection(diff.data, realDataHashs).length, realDataHashs.length
  describe 'merge', () ->
    it 'should merge two branches', () ->
      strategy = (path, value1Hash, value2Hash) -> value2Hash
      oldHead = testBranchA.head
      head = testBranchA.merge branch: testBranchB, strategy: strategy
      diff = repo.diff oldHead, head
      for each in dataB
        for key, value of each
          assert.ok (diff.data[key] == value) or (diff.data[key] == undefined)
  describe 'commit deletes', ->
    it 'should delete data', ->
      data = {'b/c': null, 'b/f/a': null, 'b/f/g': null, 'a': 1}
      testBranchB.commit data
      testData testBranchB, data
  describe 'treeAtPath', ->
    it 'should read the root tree', ->
      tree = testBranchA.treeAtPath ''
      assert.ok tree.childData
    it 'should read a child tree', ->
      tree = testBranchA.treeAtPath 'b/f'
      assert.equal tree.childData.g, 'hash7'

