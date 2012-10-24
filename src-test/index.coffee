
assert = require 'assert'
{Store, backend} = require '../lib/index'
async = require 'async'
_ = require 'underscore'
hash = require('../lib/utils').hash

home = process.env.HOME
#store = new Store(new backend.FileSystem(home+'/test1'))
store = new Store(new backend.Memory())
[testBranchA, testBranchB, testBranchC, testBranchD] = (store.branch() for each in [1,2,3,4])

testData = (branch, data, cb) ->
  testEach = (each, cb) ->
    branch.read path: each, (err, value) ->
      assert.equal value, data[each]
      cb()
  async.forEach _.keys(data), testEach, cb

commitData = ({branch, data, ref}, cb) ->
  branch.head = ref
  async.forEachSeries data, ((each, cb) -> branch.commit each, cb), cb

readDataHashs = (hashs, cb) -> async.map hashs, ((each, cb) -> store.readData each, cb), cb
readParents = (treeHash, cb) ->
  store.readTree treeHash, (err, tree) ->
    if tree.ancestors.length == 0
      cb null, treeHash
    else
      async.map tree.ancestors, readParents, (err, res) ->
        cb null, [treeHash, res]
dataA = [
  {'a': 1, 'b/c': 3, 'b/d': 4}
  {'a': 3, 'b/c': 4, 'b/e': 2, 'b/f/g': 7}
  {'b/e': 9}
]
dataAHashes = [
  '692a351a3f0ffdcc890fd9cf9d62e63019ca3631'
  '74381a6e0e497d3c50b97907ad35e29ea091e711'
  '8b189a86fb3b5840130f2bdf9b149891afc2d240'
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
      testBranchA.commonCommit testBranchB, (err, res) ->
        assert.equal res, dataAHashes[1]
        done()
    it 'should not find a common commit', (done) ->
      testBranchA.commonCommit testBranchC, (err, res) ->
        assert.equal res, undefined
        done()
  describe 'diff', () ->
    it 'should find the diff between two trees', (done) ->
      store.diff dataAHashes[0], dataAHashes[1], (err, diff) ->
        assert.equal _.keys(diff.data).length, _.keys(dataA[1]).length
        for key, data of diff.data
          assert.equal data, hash JSON.stringify(dataA[1][key])
        assert.equal _.keys(diff.trees).length, 2
        assert.equal diff.trees['b'], '87620caa4c53d422ad3a491c511b700e1cd741c8'
        assert.equal diff.trees['b/f'], '4d42003953369bfb8978ba0902311b2cac7d4680'
        done()
    it 'should find the diff between null and a tree', (done) ->
      store.diff null, dataAHashes[0], (err, diff) ->
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
        store.diff oldHead, head, (err, res) ->
          for each in dataB
            for key, value of each
              assert.ok (res.data[key] == hash JSON.stringify value) or (res.data[key] == undefined)
          done()
  describe 'commit deletes', () ->
    it 'should delete data', (done) ->
      data = {'b/c': null, 'b/f/a': null, 'b/f/g': null, 'a': 1}
      testBranchB.commit data, (err, head) ->
        testData testBranchB, data, done

