
assert = require 'assert'
Branch = require('../lib/branch');
MemoryStore = require('../lib/backend').MemoryStore
async = require 'async'
_ = require 'underscore'
hash = require('../lib/utils').hash

home = process.env.HOME
backend = new MemoryStore()
testBranchA = new Branch (backend)
testBranchB = new Branch (backend)
testBranchC = new Branch (backend)
testBranchD = new Branch (backend)

testData = (branch, data, cb) ->
  testEach = (each, cb) ->
    branch.read path: each, (err, value) ->
      assert.equal value, data[each]
      cb()
  async.forEach _.keys(data), testEach, cb

commitData = ({branch, data, ref}, cb) ->
  first = data.shift()
  branch.commit data:first, ref: ref, (err) ->
    async.forEachSeries data, ((each, cb) -> branch.commit data:each, cb), cb

readDataHashs = (hashs, cb) -> async.map hashs, ((each, cb) -> backend.readData each, cb), cb
readParents = (treeHash, cb) ->
  backend.readTree treeHash, (err, tree) ->
    if tree.parents.length == 0
      cb null, treeHash
    else
      async.map tree.parents, readParents, (err, res) ->
        cb null, [treeHash, res]
dataA = [
  {'a': 1, 'b/c': 3, 'b/d': 4}
  {'a': 3, 'b/c': 4, 'b/e': 2, 'b/f/g': 7}
  {'b/e': 9}
]
dataAHashes = [
  '0d98dde861d25a6122638fe3d2584ac13b7ec186'
  '8509ccf2758f15f7ff4991de5c9ddb57372c991a'
  '81a8f5dcf70ee8418f667058b884d203ecfe9561'
]

dataB = [
  {'b/f': 5}
  {'c/a': 1}
  {'a': 3, 'u': 7}
  {'b/c': 5, 'b/e': 1, 'b/f/a': 9}
]
dataC = [dataB[0], dataB[1]]
dataD = ['f/g': 88]
commitB = {data: dataB, ref: dataAHashes[1], branch: testBranchB}
commitC = {data: dataC, branch: testBranchC}

describe 'branch', () ->
  describe 'commit', () ->
    it 'should commit and read objects', (done) ->
      testBranchA.commit data: dataA[0], (err, head) ->
        assert.equal head, dataAHashes[0]
        testData testBranchA, dataA[0], done
    it 'should create a child commit', (done) ->
      testBranchA.commit data: dataA[1], (err, head) ->
        assert.equal head, dataAHashes[1]
        testData testBranchA, dataA[1], () ->
          testBranchA.read path: 'b/d', (err, d) ->
            assert.equal d, dataA[0]['b/d']
            done()
    it 'should read from a previous commit', (done) ->
      head1 = testBranchA.head
      testBranchA.commit data: dataA[2], (err, head2) ->
        assert.equal head2, dataAHashes[2]
        testBranchA.read path: 'b/e', ref: head1, (err, eHead1) ->
          assert.equal eHead1, dataA[1]['b/e']
          testBranchA.read path: 'b/e', ref: head2, (err, eHead2) ->
            assert.equal eHead2, dataA[2]['b/e']
            testBranchA.read path: 'b/e', (err, eHead2) ->
              assert.equal eHead2, dataA[2]['b/e']
              done()
    it 'should create a fork', (done) ->
      commitData commitB, done
    it 'should populate more test branchs', (done) ->
      async.forEach [commitC], commitData, done
  describe 'commonCommit', () ->
    # should maybe output the path as well
    it 'should find a common commit', (done) ->
      testBranchA.commonCommit testBranchB.head, (err, res) ->
        assert.equal res, dataAHashes[1]
        done()
    it 'should not find a common commit', (done) ->
      testBranchA.commonCommit testBranchC.head, (err, res) ->
        assert.equal res, undefined
        done()
  describe 'diff', () ->
    it 'should find the diff between multiple trees', (done) ->
      testBranchA.diff dataAHashes[0], dataAHashes[1], (err, diff) ->
        assert.equal _.keys(diff.data).length, _.keys(dataA[1]).length
        for key, data of diff.data
          assert.equal data, hash JSON.stringify(dataA[1][key])
        assert.equal _.keys(diff.trees).length, 2
        assert.equal diff.trees['b'], 'f9829f19f6dc90a1671fb120b729a41168e3f507'
        assert.equal diff.trees['b/f'], '88566102a52fceeac75a9446a7594c4f12efe54d'
        done()
    it 'should find the diff between null and a tree', (done) ->
      testBranchA.diff null, dataAHashes[0], (err, diff) ->
        for key, data of diff.data
          assert.equal data, hash JSON.stringify(dataA[0][key])
        done()
    it 'should find the diff between the current head and another tree', (done) ->
      testBranchA.diff testBranchB.head, (err, diff) ->
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
  ###describe 'merge', () ->
    it 'should merge two branches', () ->
      testBranchA.merge 
