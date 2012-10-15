
assert = require 'assert'
Branch = require('../lib/branch');
Store = require('../lib/store')
FileSystem = require('../lib/backends').FileSystem
Memory = require('../lib/backends').Memory
async = require 'async'
_ = require 'underscore'
hash = require('../lib/utils').hash

home = process.env.HOME
backend = new Store(new FileSystem(home+'/test1'))
#backend = new Store(new Memory())
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
  branch.head = ref
  async.forEachSeries data, ((each, cb) -> branch.commit each, cb), cb

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
  '988ea78f5200c52f2fbe94c0fe1f47c7f2b82d3c'
  '4652680140ae3c38eb2c83b60fcef8aef16e5e29'
  '096d1a7cbc45a862b35389b907c57c5615d0b984'
]

dataB = [
  {'b/h': 5}
  {'c/a': 1}
  {'a': 3, 'u': 7}
  {'b/c': 5, 'b/e': 1, 'b/f/a': 9}
]
dataC = [dataB[0], dataB[1]]
commitB = {data: dataB, ref: dataAHashes[1], branch: testBranchB}
commitC = {data: dataC, branch: testBranchC}

describe 'branch', () ->
  describe 'commit', () ->
    it 'should commit and read objects', (done) ->
      testBranchA.commit dataA[0], (err, head) ->
        assert.equal head, dataAHashes[0]
        testData testBranchA, dataA[0], done
    it 'should create a child commit', (done) ->
      testBranchA.commit dataA[1], (err, head) ->
        assert.equal head, dataAHashes[1]
        testData testBranchA, dataA[1], () ->
          testBranchA.read path: 'b/d', (err, d) ->
            assert.equal d, dataA[0]['b/d']
            done()
    it 'should read from a previous commit', (done) ->
      head1 = testBranchA.head
      testBranchA.commit dataA[2], (err, head2) ->
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
    it 'should populate more test branches', (done) ->
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
    it 'should find the diff between two trees', (done) ->
      testBranchA.diff dataAHashes[0], dataAHashes[1], (err, diff) ->
        assert.equal _.keys(diff.data).length, _.keys(dataA[1]).length
        for key, data of diff.data
          assert.equal data, hash JSON.stringify(dataA[1][key])
        assert.equal _.keys(diff.trees).length, 2
        assert.equal diff.trees['b'], '084de2796dd543036931c936744c1b17ac8b26ae'
        assert.equal diff.trees['b/f'], '89d8b6cb2c831c292d6430c52abe5f7d96344b37'
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
  describe 'merge', () ->
    it 'should merge two branches', (done) ->
      strategy = (path, value1Hash, value2Hash, cb) -> cb null, value2Hash
      testBranchA.merge branch: testBranchB, strategy: strategy, (err, head) ->
        testBranchA.diff head, (err, res) ->
          for each in dataB
            for key, value of each
              assert.ok (res.data[key] == hash JSON.stringify value) or (res.data[key] == undefined)
          done()
  describe 'commit deletes', () ->
    it 'should delete data', (done) ->
      data = {'b/c': null, 'b/f/a': null, 'b/f/g': null, 'a': 1}
      testBranchB.commit data, (err, head) ->
        testData testBranchB, data, done

