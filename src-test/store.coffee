
assert = require 'assert'
Store = require('../lib/store');
FileStore = require('../lib/backend').FileStore

home = process.env.HOME
testStore1 = new Store (new FileStore home+'/test-store1')
testStore2 = new Store (new FileStore home+'/test-store2')

describe 'store', () ->
  describe 'Commit', () ->
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

