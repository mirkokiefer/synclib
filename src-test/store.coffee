
assert = require 'assert'
Store = require('../lib/store');
MemoryStore = require('../lib/backend').MemoryStore
async = require 'async'
_ = require 'underscore'



home = process.env.HOME
testStoreA = new Store (new MemoryStore())
testStoreB = new Store (new MemoryStore())
testStoreC = new Store (new MemoryStore())

testData = (store, data, cb) ->
  testEach = (each, cb) ->
    store.read path: each, (err, value) ->
      assert.equal value, data[each]
      cb()
  async.forEach _.keys(data), testEach, cb

commitData = (store, data, cb) ->
  async.forEachSeries data, ((each, cb) -> store.commit data:each, cb), cb

dataA1 = 'a': 1, 'b/c': 3, 'b/d': 4
dataA2 = 'a': 3, 'b/c': 4, 'b/e': 2, 'b/f/g': 7
dataA3 = 'b/e': 3

dataB1 = dataA1
dataB2 = dataA2
dataB3 = 'b/f': 5
dataB4 = 'c/a': 1

describe 'store', () ->
  describe 'commit', () ->
    it 'should commit and read objects', (done) ->
      testStoreA.commit data: dataA1, () ->
        testData testStoreA, dataA1, done
    it 'should create a child commit', (done) ->
      testStoreA.commit data: dataA2, () ->
        testData testStoreA, dataA2, () ->
          testStoreA.read path: 'b/d', (err, d) ->
            assert.equal d, dataA1['b/d']
            done()
    it 'should create a forking commit', (done) ->
      head1 = testStoreA.head
      testStoreA.commit data: dataA3, (err, head2) ->
        testStoreA.read path: 'b/e', ref: head1, (err, eHead1) ->
          assert.equal eHead1, dataA2['b/e']
          testStoreA.read path: 'b/e', ref: head2, (err, eHead2) ->
            assert.equal eHead2, dataA3['b/e']
            testStoreA.read path: 'b/e', (err, eHead2) ->
              assert.equal eHead2, dataA3['b/e']
              done()
    it 'should populate the second store', (done) ->
      data = [dataB1, dataB2, dataB3, dataB4]
      commitData testStoreB, data, () ->
        testStoreB.read path: 'c/a', (err, a) ->
          assert.equal a, dataB4['c/a']
          done()
    it 'should populate the third store', (done) ->
      data = [dataB3, dataB4]
      commitData testStoreC, data, done
  describe 'commonCommit', () ->
    it 'should find a common commit', (done) ->
      testStoreA.commonCommit store: testStoreB, (err, res) ->
        assert.equal res, '8509ccf2758f15f7ff4991de5c9ddb57372c991a'
        done()
    it 'should not find a common commit', (done) ->
      testStoreA.commonCommit store: testStoreC, (err, res) ->
        assert.equal res, undefined
        done()
