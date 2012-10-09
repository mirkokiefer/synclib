
assert = require 'assert'
Store = require('../lib/store');
MemoryStore = require('../lib/backend').MemoryStore
async = require 'async'
_ = require 'underscore'
hash = require('../lib/utils').hash

home = process.env.HOME
backend = new MemoryStore()
testStoreA = new Store (backend)
testStoreB = new Store (backend)
testStoreC = new Store (backend)
testStoreD = new Store (backend)

testData = (store, data, cb) ->
  testEach = (each, cb) ->
    store.read path: each, (err, value) ->
      assert.equal value, data[each]
      cb()
  async.forEach _.keys(data), testEach, cb

commitData = ({store, data}, cb) ->
  async.forEachSeries data, ((each, cb) -> store.commit data:each, cb), cb

readDataHashs = (hashs, cb) -> async.map hashs, ((each, cb) -> backend.readData each, cb), cb

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
    # should output the path as well
    it 'should find a common commit', (done) ->
      testStoreA.commonCommit [testStoreB.head], (err, res) ->
        assert.equal res, '8509ccf2758f15f7ff4991de5c9ddb57372c991a'
        done()
    it 'should not find a common commit', (done) ->
      testStoreA.commonCommit [testStoreC.head], (err, res) ->
        assert.equal res, undefined
        done()
    it 'should find a common commit among three stores', (done) ->
      testStoreA.commonCommit [testStoreB.head, testStoreD.head], (err, res) ->
        assert.equal res, '0d98dde861d25a6122638fe3d2584ac13b7ec186'
        done()
    it 'should not find a common commit among four stores', (done) ->
      testStoreA.commonCommit [testStoreB.head, testStoreC.head, testStoreD.head], (err, res) ->
        assert.equal res, undefined
        done()
  describe 'diff', () ->
    it 'should find the diff between multiple trees', (done) ->
      testStoreA.diff dataAHashes[0], dataAHashes[1], (err, diff) ->
        assert.equal _.keys(diff.data).length, _.keys(dataA[1]).length
        for key, data of diff.data
          assert.equal data, hash JSON.stringify(dataA[1][key])
        assert.equal _.keys(diff.trees).length, 2
        assert.equal diff.trees['b'], 'f9829f19f6dc90a1671fb120b729a41168e3f507'
        assert.equal diff.trees['b/f'], '88566102a52fceeac75a9446a7594c4f12efe54d'
        done()
    it 'should find the diff between null and a tree', (done) ->
      testStoreA.diff null, dataAHashes[0], (err, diff) ->
        for key, data of diff.data
          assert.equal data, hash JSON.stringify(dataA[0][key])
        done()
  describe 'diffSince', () ->
    it 'should find the diff between trees in the past and the current head', (done) ->
      testStoreA.diffSince [dataAHashes[0]], (err, diff) ->
        realData = _.union(_.values(dataA[1]), _.values(dataA[2]))
        realDataHashs = (hash JSON.stringify(each) for each in realData)
        assert.equal _.intersection(diff.data, realDataHashs).length, realData.length
        done()
    it 'should find the diff between a tree in the past that doesnt exist and the current head', (done) ->
      testStoreA.diffSince [null], (err, diff) ->
        realDataHashs = (hash JSON.stringify(each) for each in _.values(dataA[0]))
        assert.equal _.intersection(diff.data, realDataHashs).length, realDataHashs.length
        done()

