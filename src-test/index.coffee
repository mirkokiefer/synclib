
assert = require 'assert'
{Repository} = require '../lib/index'
async = require 'async'
_ = require 'underscore'
{union, difference, keys, values, pluck, contains, where} = _
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

testData = (branch, data) ->
  for path, value of data
    assert.equal branch.dataAtPath(path), value

testCommitAncestors = (commitHash, hashs) ->
  [first, rest...] = hashs
  assert.equal commitHash, first
  if rest.length > 0
    {ancestors} = repo._commitStore.read commitHash
    testCommitAncestors ancestors[0], rest

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
    it 'should commit and read objects', () ->
      head = testBranchA.commit dataA[0]
      assert.equal head, dataAHashes[0]
      testData testBranchA, dataA[0]
    it 'should create a child commit', () ->
      head = testBranchA.commit dataA[1]
      assert.equal head, dataAHashes[1]
      testData testBranchA, dataA[1]
      d = testBranchA.dataAtPath 'b/d'
      assert.equal d, dataA[0]['b/d']
    it 'should not create a new commit', ->
      oldHead = testBranchA.head
      head = testBranchA.commit dataA[1]
      assert.equal head, oldHead
    it 'should read from a previous commit', () ->
      head1 = testBranchA.head
      head2 = testBranchA.commit dataA[2]
      assert.equal head2, dataAHashes[2]
      eHead1 = repo.dataAtPath head1, 'b/e'
      assert.equal eHead1, dataA[1]['b/e']
      eHead2 = repo.dataAtPath head2, 'b/e'
      assert.equal eHead2, dataA[2]['b/e']
      eHead2 = testBranchA.dataAtPath 'b/e'
      assert.equal eHead2, dataA[2]['b/e']
    it 'should populate more test branches', () ->
      commitData = ({branch, data, ref}) ->
        branch.head = ref
        branch.commit each for each in data
      commitData each for each in [commitB, commitC, commitD]
      testCommitAncestors testBranchB.head, dataBHashes
  describe 'commonCommit', () ->
    # should maybe output the path as well
    it 'should find a common commit', ->
      res1 = testBranchA.commonCommit testBranchB
      assert.equal res1, dataAHashes[1]
      res2 = testBranchA.commonCommit testBranchD
      assert.equal res2, dataAHashes[1]
      res3 = testBranchA.commonCommit dataAHashes[0]
      assert.equal res3, dataAHashes[0]
      res4 = repo.commonCommit dataAHashes[2], dataAHashes[0]
      assert.equal res4, dataAHashes[0]
      res5 = repo.commonCommit dataAHashes[0], dataAHashes[2]
      assert.equal res5, dataAHashes[0]
    it 'should find a common commit with paths', ->
      res1 = testBranchA.commonCommitWithPaths testBranchB
      expectedCommit1Path = [dataAHashes[1], dataAHashes[2]]
      expectedCommit2Path = dataBHashes.concat dataAHashes[1]
      assertArray res1.commit1Path, expectedCommit1Path
      assertArray res1.commit2Path, expectedCommit2Path
      res2 = testBranchA.commonCommitWithPaths dataAHashes[0]
      assert.equal res2.commit2Path.length, 1
    it 'should not find a common commit', ->
      res = testBranchA.commonCommit testBranchC
      assert.equal res, undefined
  describe 'diff', () ->
    it 'should find the diff between two commits', ->
      diff = repo.diff dataAHashes[0], dataAHashes[1]
      assert.equal diff.values.length, _.keys(dataA[1]).length
      for {path, value} in diff.values
        assert.equal value, dataA[1][path]
      assert.equal diff.trees.length, 3
    it 'should find the diff between null and a commit', ->
      diff = repo.diff null, dataAHashes[0]
      for {path, value} in diff.values
        assert.equal value, dataA[0][path]
    it 'should find the diff between the current head and another commit', ->
      diff = testBranchA.diff testBranchB
      assert.ok diff
  describe 'deltaHashs', () ->
    it 'should find the diff as hashes between heads in the past and the current head', () ->
      diff = testBranchA.deltaHashs from: [dataAHashes[0]]
      realDataHashs = _.union(_.values(dataA[1]), _.values(dataA[2]))
      assertArray diff.values, realDataHashs
    it 'should find the diff between a head in the past that doesnt exist and the current head', () ->
      diff = testBranchA.deltaHashs from: ['non-existing']
      realDataHashs = _.union _.values(dataA[0]), _.values(dataA[1]), _.values(dataA[2])
      assertArray diff.values, realDataHashs
    it 'should work without a ref - returns the full diff', () ->
      diff = testBranchA.deltaHashs()
      realDataHashs = _.union _.values(dataA[0]), _.values(dataA[1]), _.values(dataA[2])
      assertArray diff.values, realDataHashs
    it 'should compute the value to a disconnected branch', ->
      diff = testBranchA.deltaHashs to: [testBranchC]
      realDataHashs = _.union _.values(dataC[0]), _.values(dataC[1])
      assertArray diff.values, realDataHashs
    it 'should compute the value from a single commit to multiple commits', ->
      diff = testBranchD.deltaHashs to: [testBranchA, testBranchB]
      realDataHashs = _.union _.values(dataA[2]), _.values(dataB[3])
      assertArray diff.values, realDataHashs
    it 'should compute the delta from multiple commits to a single commit', ->
      diff = testBranchD.deltaHashs from: [testBranchA, testBranchB, testBranchC]
      realDataHashs = union values(dataD[0]), values(dataD[1])
      assertArray diff.values, realDataHashs
  describe 'delta', () ->
    it 'should find the diff including the actual trees and commits', () ->
      diff = repo.deltaData testBranchA.deltaHashs from: [dataAHashes[0]]
      assert.equal diff.trees.length, 5
      assert.ok diff.trees[0].length > 40
      assert.ok diff.commits[0].length > 40
  describe 'merge', () ->
    assertMerge = (branch, expectedData, expectedHeads) ->
      head = repo._commitStore.read branch.head
      assertArray head.ancestors, expectedHeads
      assertPathData branch.allPaths(), expectedData
    it 'should merge branchB into branchA', () ->
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
      testBranchA.merge ref: testBranchB, strategy: strategy
      assertMerge testBranchA, expectedData, [oldHead, testBranchB.head]
    it 'should merge branchA into branchB', () ->
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
      testBranchB.merge ref: dataAHashes[2]
      assertMerge testBranchB, expectedData, [oldHead, dataAHashes[2]]
      assert.equal testBranchB.head, testBranchA.head
    it 'should merge branchA into branchC (they do not have a common commit)', () ->
      expectedData = [
        { path: 'b/f/g', value: 'hashA 1.3' },
        { path: 'b/c', value: 'hashA 1.1' },
        { path: 'b/d', value: 'hashA 0.2' },
        { path: 'b/e', value: 'hashA 2.0' },
        { path: 'c/a', value: 'hashC 0.1' },
        { path: 'a', value: 'hashC 1.0' }
      ]
      oldHeadC = testBranchC.head
      testBranchC.merge ref: dataAHashes[2]
      assertMerge testBranchC, expectedData, [oldHeadC, dataAHashes[2]]
  describe 'commit deletes', ->
    it 'should delete data', ->
      data = {'b/c': null, 'b/f/a': null, 'b/f/g': null, 'a': 1}
      testBranchB.commit data
      testData testBranchB, data
  describe 'treeAtPath', ->
    it 'should read the root tree', ->
      tree = testBranchA.treeAtPath ''
      assert.ok tree.childData
    it 'should read a child tree', ->
      tree = testBranchA.treeAtPath 'b/f'
      assert.equal tree.childData.g, dataA[1]['b/f/g']
  describe 'paths', ->
    it 'should return all tracked paths', ->
      testBranch = repo.branch dataAHashes[0]
      expectedPaths = keys dataA[0]
      paths = pluck testBranch.allPaths(), 'path'
      assert.equal difference(paths, expectedPaths).length, 0
      assert.equal difference(expectedPaths, paths).length, 0
