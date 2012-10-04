
assert = require 'assert'
Store = require('../lib/store');
FileStore = require('../lib/backend').FileStore
async = require 'async'
_ = require 'underscore'

home = process.env.HOME
testStore1 = new Store (new FileStore home+'/test-store1')
testStore2 = new Store (new FileStore home+'/test-store2')

testData = (store, data, cb) ->
  testEach = (each, cb) ->
    store.read each, (err, value) ->
      assert.equal value, data[each]
      cb()
  async.forEach _.keys(data), testEach, cb

describe 'store', () ->
  describe 'first commit', () ->
    it 'should commit and read objects', (done) ->
      data =
        'a': 1
        'b/c': 3
        'b/d': 4
      testStore1.commit data, () ->
        testStore1.read 'a', (err, a) ->
          assert.equal a, data.a
          testStore1.read 'b/c', (err, c) ->
            assert.equal c, data['b/c']
            done()
  describe 'subsequent commit', () ->
    it 'should create a child commit', (done) ->
      data =
        'a': 3
        'b/c': 4
        'b/e': 2
      testStore1.commit data, () ->
        testData testStore1, data, () ->
          testStore1.read 'b/d', (err, d) ->
            assert.equal d, 4
            done()
