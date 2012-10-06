
assert = require 'assert'
Store = require('../lib/store');
MemoryStore = require('../lib/backend').MemoryStore
async = require 'async'
_ = require 'underscore'



home = process.env.HOME
testStoreA = new Store (new MemoryStore())
testStoreB = new Store (new MemoryStore())
testStoreC = new Store (new MemoryStore())
testStoreD = new Store (new MemoryStore())

testData = (store, data, cb) ->
  testEach = (each, cb) ->
    store.read path: each, (err, value) ->
      assert.equal value, data[each]
      cb()
  async.forEach _.keys(data), testEach, cb

commitData = ({store, data}, cb) ->
  async.forEachSeries data, ((each, cb) -> store.commit data:each, cb), cb

dataA = [
  {'a': 1, 'b/c': 3, 'b/d': 4}
  {'a': 3, 'b/c': 4, 'b/e': 2, 'b/f/g': 7}
  {'b/e': 3}
]
dataAHashes = [
  '0d98dde861d25a6122638fe3d2584ac13b7ec186'
  '8509ccf2758f15f7ff4991de5c9ddb57372c991a'
  '6fb1b35a1d1324a2c221301e48818fbf69f66727'
]
dataB = [
  dataA[0]
  dataA[1]
  {'b/f': 5}
  {'c/a': 1}
]
dataC = [dataB[2], dataB[3]]
dataD = [dataA[0], dataA[2]]

describe 'store', () ->
  describe 'commit', () ->
    it 'should commit and read objects', (done) ->
      testStoreA.commit data: dataA[0], (err, head) ->
        assert.equal head, dataAHashes[0]
        testData testStoreA, dataA[0], done
    it 'should create a child commit', (done) ->
      testStoreA.commit data: dataA[1], (err, head) ->
        assert.equal head, dataAHashes[1]
        testData testStoreA, dataA[1], () ->
          testStoreA.read path: 'b/d', (err, d) ->
            assert.equal d, dataA[0]['b/d']
            done()
    it 'should create a forking commit', (done) ->
      head1 = testStoreA.head
      testStoreA.commit data: dataA[2], (err, head2) ->
        assert.equal head2, dataAHashes[2]
        testStoreA.read path: 'b/e', ref: head1, (err, eHead1) ->
          assert.equal eHead1, dataA[1]['b/e']
          testStoreA.read path: 'b/e', ref: head2, (err, eHead2) ->
            assert.equal eHead2, dataA[2]['b/e']
            testStoreA.read path: 'b/e', (err, eHead2) ->
              assert.equal eHead2, dataA[2]['b/e']
              done()
    it 'should populate more test stores', (done) ->
      data = [
        {data: dataB, store: testStoreB}
        {data: dataC, store: testStoreC}
        {data: dataD, store: testStoreD}
      ]
      async.forEach data, commitData, done
  describe 'commonCommit', () ->
    it 'should find a common commit', (done) ->
      testStoreA.commonCommit [testStoreB], (err, res) ->
        assert.equal res, '8509ccf2758f15f7ff4991de5c9ddb57372c991a'
        done()
    it 'should not find a common commit', (done) ->
      testStoreA.commonCommit [testStoreC], (err, res) ->
        assert.equal res, undefined
        done()
    it 'should find a common commit among three stores', (done) ->
      testStoreA.commonCommit [testStoreB, testStoreD], (err, res) ->
        assert.equal res, '0d98dde861d25a6122638fe3d2584ac13b7ec186'
        done()
    it 'should not find a common commit among four stores', (done) ->
      testStoreA.commonCommit [testStoreB, testStoreC, testStoreD], (err, res) ->
        assert.equal res, undefined
        done()
  describe 'diff', () ->
    it 'should find the diff between multiple stores', (done) ->
      testStoreA.diff dataAHashes[0], dataAHashes[1], (err, diff) ->
        assert.equal diff.trees.length, 2
        assert.equal diff.data.length, 4
        done()
