
assert = require 'assert'
Store = require('../lib/store');
MemoryStore = require('../lib/backend').MemoryStore
async = require 'async'
_ = require 'underscore'



home = process.env.HOME
testStoreA = new Store (new MemoryStore())
testStoreB = new Store (new MemoryStore())

testData = (store, data, cb) ->
  testEach = (each, cb) ->
    store.read path: each, (err, value) ->
      assert.equal value, data[each]
      cb()
  async.forEach _.keys(data), testEach, cb

dataA1 = 'a': 1, 'b/c': 3, 'b/d': 4
dataA2 = 'a': 3, 'b/c': 4, 'b/e': 2, 'b/f/g': 7
dataA3 = 'b/e': 3

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
  
