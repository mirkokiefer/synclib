
assert = require 'assert'
{Repository} = require '../lib/index'
async = require 'async'
_ = require 'underscore'
{union, difference, keys, values, pluck, contains, where, pairs} = _
repo = new Repository()
[testBranchA, testBranchB, testBranchC, testBranchD] = (repo.branch() for each in ['a', 'b', 'c', 'd'])

assertArray = (array, expectedArray) ->
  assert.ok contains(array, each) for each in expectedArray
  assert.ok contains(expectedArray, each) for each in array
assertPathData = (data, expected) ->
  assert.equal data.length, expected.length
  for {path, value} in expected
    found = where data, path: path
    assert.equal found.length, 1
    assert.equal found[0].value, value

testData = (branch, data, cb) ->
  forEach = ([path, expectedValue], cb) ->
    branch.dataAtPath path, (err, value) ->
      assert.equal value, expectedValue
      cb()
  async.forEach pairs(data), forEach, cb

testCommitAncestors = (commitHash, hashs, cb) ->
  [first, rest...] = hashs
  assert.equal commitHash, first
  if rest.length > 0
    repo._commitStore.read commitHash, (err, {ancestors}) ->
      testCommitAncestors ancestors[0], rest, cb

dataA = [
  {'a': "hashA 0.0", 'b/c': "hashA 0.1", 'b/d': "hashA 0.2"}
  {'a': "hashA 1.0", 'b/c': "hashA 1.1", 'b/e': "hashA 1.2", 'b/f/g': "hashA 1.3"}
  {'b/e': "hashA 2.0"}
]
dataB = [
  {'b/h': "hashB 0.0"}
  {'c/a': "hashB 1.0"}
  {'a': "hashB 2.0", 'u': "hashB 2.1"}
  {'b/c': "hashB 3.0", 'b/e': "hashB 3.1", 'b/f/a': "hashB 3.2"}
]
dataC = [
  {'a': 'hashC 0.0', 'c/a': 'hashC 0.1'}
  {'a': 'hashC 1.0'}
]
dataD = [
  {'e': 'hashD 0.0'}
  {'b/f/b': 'hashD 1.0'}
]
dataAHashes = [
  'b2ef9fc4cb736db036b5dc098f1054546bcaf1be'
  '5bc500f2e12c1cf10719925cf1848413965603ff'
  '7693e2f18011f0a995e26880f17230fd36f04c5d'
]
dataBHashes = [
  'fca94cfa923725e3c6318bb5eef14dffd9c38091'
  'ae1287e2835cfea8fca7a880dcfe09ecf4dfb428'
  'c3015798e734dc9bbc3e8fc58e677e2eacc1a377'
  '68d1f53596baa4bdc69208a06538e88d9612e77a'
]
commitB = {data: dataB, ref: dataAHashes[1], branch: testBranchB}
commitC = {data: dataC, branch: testBranchC}
commitD = {data: dataD, ref: dataBHashes[1], branch: testBranchD}

###
a graphical branch view:

                         d0 - d1 <- D
                       /
          b0 - b1 - b2 - b3 <- B
        /
a0 - a1 - a2 <- A

c0 - c1 <- C
###

describe 'branch', () ->
  describe 'commit', () ->
    it 'should commit and read objects', (done) ->
      testBranchA.commit dataA[0], (err, head) ->
        assert.equal head, dataAHashes[0]
        testData testBranchA, dataA[0], done
    it 'should create a child commit', (done) ->
      testBranchA.commit dataA[1], (err, head) ->
        assert.equal head, dataAHashes[1]
        testData testBranchA, dataA[1], ->
          testBranchA.dataAtPath 'b/d', (err, d) ->
            assert.equal d, dataA[0]['b/d']
            done()
    it 'should not create a new commit', (done) ->
      oldHead = testBranchA.head
      testBranchA.commit dataA[1], (err, head) ->
        assert.equal head, oldHead
        done()
    it 'should read from a previous commit', (done) ->
      head1 = testBranchA.head
      testBranchA.commit dataA[2], (err, head2) ->
        assert.equal head2, dataAHashes[2]
        repo.dataAtPath head1, 'b/e', (err, eHead1) ->
          assert.equal eHead1, dataA[1]['b/e']
          repo.dataAtPath head2, 'b/e', (err, eHead2) ->
            assert.equal eHead2, dataA[2]['b/e']
            done()
    it 'should populate more test branches', (done) ->
      commitData = ({branch, data, ref}, cb) ->
        branch.head = ref
        async.forEach data, ((each, cb) -> branch.commit each, cb), cb
      async.forEach [commitB, commitC, commitD], commitData, ->
        testCommitAncestors testBranchB.head, dataBHashes
        done()
  describe 'commonCommit', () ->
    # should maybe output the path as well
    it 'should find a common commit', (done) ->
      tests = [
        (cb) -> testBranchA.commonCommit testBranchB, cb
        (cb) -> testBranchA.commonCommit testBranchD, cb
        (cb) -> testBranchA.commonCommit dataAHashes[0], cb
        (cb) -> repo.commonCommit dataAHashes[2], dataAHashes[0], cb
        (cb) -> repo.commonCommit dataAHashes[0], dataAHashes[2], cb
      ]
      async.series tests, (err, results) ->
        expectedResults = [dataAHashes[1], dataAHashes[1], dataAHashes[0], dataAHashes[0], dataAHashes[0]]
        for each, i in expectedResults
          assert.equal results[i], each
        done()
    it 'should find a common commit with paths', (done) ->
      testBranchA.commonCommitWithPaths testBranchB, (err, res1) ->
        expectedCommit1Path = [dataAHashes[1], dataAHashes[2]]
        expectedCommit2Path = dataBHashes.concat dataAHashes[1]
        assertArray res1.commit1Path, expectedCommit1Path
        assertArray res1.commit2Path, expectedCommit2Path
        testBranchA.commonCommitWithPaths dataAHashes[0], (err, res2) ->
          assert.equal res2.commit2Path.length, 1
          done()
    it 'should not find a common commit', (done) ->
      testBranchA.commonCommit testBranchC, (err, res) ->
        assert.equal res, undefined
        done()
  describe 'diff', () ->
    it 'should find the diff between two commits', (done) ->
      repo.diff dataAHashes[0], dataAHashes[1], (err, diff) ->
        assert.equal diff.values.length, _.keys(dataA[1]).length
        for {path, value} in diff.values
          assert.equal value, dataA[1][path]
        assert.equal diff.trees.length, 3
        done()
    it 'should find the diff between null and a commit', (done) ->
      repo.diff null, dataAHashes[0], (err, diff) ->
        for {path, value} in diff.values
          assert.equal value, dataA[0][path]
        done()
    it 'should find the diff between the current head and another commit', (done) ->
      testBranchA.diff testBranchB, (err, diff) ->
        assert.ok diff
        done()
  describe 'delta', () ->
    it 'should find the diff as hashes between heads in the past and the current head', (done) ->
      testBranchA.delta from: [dataAHashes[0]], (err, diff) ->
        realDataHashs = _.union(_.values(dataA[1]), _.values(dataA[2]))
        assertArray diff.values, realDataHashs
        assertArray pluck(diff.commits, 'hash'), [dataAHashes[1], dataAHashes[2]]
        expectedSerialized = [
          '[["5bc500f2e12c1cf10719925cf1848413965603ff"],"61b4e5cba3e16752ce4d9b30cc1509ff62890293",[]]'
          '[["b2ef9fc4cb736db036b5dc098f1054546bcaf1be"],"1aebadc7bcec1e477ba1cb9a9a4536b35f398779",[]]'
        ]
        assertArray pluck(diff.commits, 'data'), expectedSerialized
        done()
    it 'should find the diff between a head in the past that doesnt exist and the current head', (done) ->
      testBranchA.delta from: ['non-existing'], (err, diff) ->
        realDataHashs = _.union _.values(dataA[0]), _.values(dataA[1]), _.values(dataA[2])
        assertArray diff.values, realDataHashs
        done()
    it 'should work without a ref - returns the full diff', (done) ->
      testBranchA.delta {}, (err, diff) ->
        realDataHashs = _.union _.values(dataA[0]), _.values(dataA[1]), _.values(dataA[2])
        assertArray diff.values, realDataHashs
        done()
    it 'should compute the value to a disconnected branch', (done) ->
      testBranchA.delta to: [testBranchC], (err, diff) ->
        realDataHashs = _.union _.values(dataC[0]), _.values(dataC[1])
        assertArray diff.values, realDataHashs
        done()
    it 'should compute the value from a single commit to multiple commits', (done) ->
      testBranchD.delta to: [testBranchA, testBranchB], (err, diff) ->
        realDataHashs = _.union _.values(dataA[2]), _.values(dataB[3])
        assertArray diff.values, realDataHashs
        done()
    it 'should compute the delta from multiple commits to a single commit', (done) ->
      testBranchD.delta from: [testBranchA, testBranchB, testBranchC], (err, diff) ->
        realDataHashs = union values(dataD[0]), values(dataD[1])
        assertArray diff.values, realDataHashs
        done()
  describe 'merge', () ->
    assertMerge = (branch, expectedData, expectedHeads, cb) ->
      repo._commitStore.read branch.head, (err, head) ->
        assertArray head.ancestors, expectedHeads
        branch.allPaths (err, paths) ->
          assertPathData paths, expectedData
          cb()
    it 'should merge branchB into branchA', (done) ->
      expectedData = [
        { path: 'b/f/a', value: 'hashB 3.2' },
        { path: 'b/f/g', value: 'hashA 1.3' },
        { path: 'b/c', value: 'hashB 3.0' },
        { path: 'b/d', value: 'hashA 0.2' },
        { path: 'b/e', value: 'hashB 3.1' },
        { path: 'b/h', value: 'hashB 0.0' },
        { path: 'c/a', value: 'hashB 1.0' },
        { path: 'a', value: 'hashB 2.0' },
        { path: 'u', value: 'hashB 2.1' }
      ]
      oldHead = testBranchA.head
      strategy = (path, value1Hash, value2Hash) -> value2Hash
      testBranchA.merge ref: testBranchB, strategy: strategy, ->
        assertMerge testBranchA, expectedData, [oldHead, testBranchB.head], done
    it 'should merge branchA into branchB', (done) ->
      expectedData = [
        { path: 'b/f/a', value: 'hashB 3.2' },
        { path: 'b/f/g', value: 'hashA 1.3' },
        { path: 'b/c', value: 'hashB 3.0' },
        { path: 'b/d', value: 'hashA 0.2' },
        { path: 'b/e', value: 'hashB 3.1' },
        { path: 'b/h', value: 'hashB 0.0' },
        { path: 'c/a', value: 'hashB 1.0' },
        { path: 'a', value: 'hashB 2.0' },
        { path: 'u', value: 'hashB 2.1' }
      ]
      oldHead = testBranchB.head
      testBranchB.merge ref: dataAHashes[2], ->
        assert.equal testBranchB.head, testBranchA.head
        assertMerge testBranchB, expectedData, [oldHead, dataAHashes[2]], done
    it 'should merge branchA into branchC (they do not have a common commit)', (done) ->
      expectedData = [
        { path: 'b/f/g', value: 'hashA 1.3' },
        { path: 'b/c', value: 'hashA 1.1' },
        { path: 'b/d', value: 'hashA 0.2' },
        { path: 'b/e', value: 'hashA 2.0' },
        { path: 'c/a', value: 'hashC 0.1' },
        { path: 'a', value: 'hashC 1.0' }
      ]
      oldHeadC = testBranchC.head
      testBranchC.merge ref: dataAHashes[2], ->
        assertMerge testBranchC, expectedData, [oldHeadC, dataAHashes[2]], done
    it 'should merge branchA into an empty branch', (done) ->
      emptyBranch = repo.branch()
      emptyBranch.merge ref: testBranchA, (err, head) ->
        assert.equal head, testBranchA.head
        done()
  describe 'commit deletes', ->
    it 'should delete data', (done) ->
      data = {'b/c': null, 'b/f/a': null, 'b/f/g': null, 'a': 1}
      testBranchB.commit data, (err, head) ->
        testData testBranchB, data, done
  describe 'treeAtPath', ->
    it 'should read the root tree', (done) ->
      testBranchA.treeAtPath '', (err, tree) ->
        assert.ok tree.childData
        done()
    it 'should read a child tree', (done) ->
      testBranchA.treeAtPath 'b/f', (err, tree) ->
        assert.equal tree.childData.g, dataA[1]['b/f/g']
        done()
  describe 'paths', (done) ->
    it 'should return all tracked paths', (done) ->
      testBranch = repo.branch dataAHashes[0]
      expectedPaths = keys dataA[0]
      testBranch.allPaths (err, paths) ->
        paths = pluck paths, 'path'
        assert.equal difference(paths, expectedPaths).length, 0
        assert.equal difference(expectedPaths, paths).length, 0
        done()
