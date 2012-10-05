
assert = require 'assert'
Store = require('../lib/store');
MemoryStore = require('../lib/backend').MemoryStore
async = require 'async'
_ = require 'underscore'



home = process.env.HOME
testStore1 = new Store (new MemoryStore())
testStore2 = new Store (new MemoryStore())

testData = (store, data, cb) ->
  testEach = (each, cb) ->
    store.read path: each, (err, value) ->
      assert.equal value, data[each]
      cb()
  async.forEach _.keys(data), testEach, cb

data1 = 'a': 1, 'b/c': 3, 'b/d': 4
data2 = 'a': 3, 'b/c': 4, 'b/e': 2, 'b/f/g': 7
data3 = 'b/e': 3

describe 'store', () ->
  describe 'commit', () ->
    it 'should commit and read objects', (done) ->
      testStore1.commit data: data1, () ->
        testData testStore1, data1, done
    it 'should create a child commit', (done) ->
      testStore1.commit data: data2, () ->
        testData testStore1, data2, () ->
          testStore1.read path: 'b/d', (err, d) ->
            assert.equal d, data1['b/d']
            done()
    it 'should create a forking commit', (done) ->
      head1 = testStore1.head
      testStore1.commit data: data3, (err, head2) ->
        testStore1.read path: 'b/e', ref: head1, (err, eHead1) ->
          assert.equal eHead1, data2['b/e']
          testStore1.read path: 'b/e', ref: head2, (err, eHead2) ->
            assert.equal eHead2, data3['b/e']
            testStore1.read path: 'b/e', (err, eHead2) ->
              assert.equal eHead2, data3['b/e']
              done()