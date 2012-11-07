
assert = require 'assert'
{Repository, memoryStore} = require '../lib/index'
async = require 'async'
_ = require 'underscore'

store = memoryStore()
repo = new Repository store
[testBranchA, testBranchB, testBranchC, testBranchD] = (repo.branch() for each in [1,2,3,4])

testData = (branch, data) ->
  for path, value of data
    assert.equal branch.dataAtPath(path), value

testTreeAncestors = (treeHash, hashs) ->
  [first, rest...] = hashs
  assert.equal treeHash, first
  if rest.length > 0
    tree = repo.treeStore.read treeHash
    testTreeAncestors tree.ancestors[0], rest

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
  'e90eade66b9fc267016eff49d07bc5d8a64f0dda'
  '3f0f72434191cde81c71d26dc7db96bd03435feb'
  'cca2949ddf3046f4956292e8623c731ea8c217d5'
]
dataBHashes = [
  'c6c3c788efd7d615887776c306290c45c29772cf'
  'befd62c41818e1ea39573507fd1dc1cd47f01af3'
  '2fced862788cb4272f0d1d51869dba4d3552c630'
  '872a39296a6358c4d71c5de01aa0dc4c257718bf'
]
commitB = {data: dataB, ref: dataAHashes[1], branch: testBranchB}
commitC = {data: dataC, branch: testBranchC}
commitD = {data: dataD, ref: dataBHashes[1], branch: testBranchD}

###
a graphical branch view:

                    d0 - d1 <- D
                  /
          b0 - b1 - b2 <- B
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
      testTreeAncestors testBranchB.head, dataBHashes
  describe 'commonCommit', () ->
    # should maybe output the path as well
    it 'should find a common commit', ->
      res1 = testBranchA.commonCommit testBranchB
      assert.equal res1, dataAHashes[1]
      res2 = testBranchA.commonCommit testBranchD
      assert.equal res2, dataAHashes[1]
    it 'should not find a common commit', ->
      res = testBranchA.commonCommit testBranchC
      assert.equal res, undefined
  describe 'diff', () ->
    it 'should find the diff between two trees', ->
      diff = repo.diff dataAHashes[0], dataAHashes[1]
      assert.equal diff.data.length, _.keys(dataA[1]).length
      for {path, hash} in diff.data
        assert.equal hash, dataA[1][path]
      assert.equal diff.trees.length, 3
    it 'should find the diff between null and a tree', ->
      diff = repo.diff null, dataAHashes[0]
      for {path, hash} in diff.data
        assert.equal hash, dataA[0][path]
    it 'should find the diff between the current head and another tree', ->
      diff = testBranchA.diff testBranchB
      assert.ok diff
  describe 'patchHashs', () ->
    it 'should find the diff as hashes between heads in the past and the current head', () ->
      diff = testBranchA.patchHashs from: dataAHashes[0]
      realData = _.union(_.values(dataA[1]), _.values(dataA[2]))
      assert.equal _.intersection(diff.data, realData).length, realData.length
    it 'should find the diff between a head in the past that doesnt exist and the current head', () ->
      diff = testBranchA.patchHashs from: null
      realDataHashs = _.union _.values(dataA[0]), _.values(dataA[1], _.values(dataA[2]))
      assert.equal _.intersection(diff.data, realDataHashs).length, realDataHashs.length
    it 'should work without a ref - returns the full diff', () ->
      diff = testBranchA.patchHashs()
      realDataHashs = _.union _.values(dataA[0]), _.values(dataA[1], _.values(dataA[2]))
      assert.equal _.intersection(diff.data, realDataHashs).length, realDataHashs.length
    it 'should compute the hash to a disconnected branch', ->
      diff = testBranchA.patchHashs to: testBranchC
      realDataHashs = _.union _.values(dataC[0]), _.values(dataC[1])
      assert.equal _.intersection(diff.data, realDataHashs).length, realDataHashs.length
    it 'should compute the hash to multiple trees', ->
      diff = testBranchD.patchHashs to: [testBranchA, testBranchB]
      realDataHashs = _.union _.values(dataA[2]), _.values(dataB[3])
      assert.equal _.intersection(diff.data, realDataHashs).length, realDataHashs.length
  describe 'patch', () ->
    it 'should find the diff including the actual trees between heads in the past and the current head', () ->
      diff = repo.patchData testBranchA.patchHashs from: dataAHashes[0]
      assert.equal diff.trees.length, 5
      assert.ok diff.trees[0].length > 40
  describe 'merge', () ->
    it 'should merge branchB into branchA', () ->
      strategy = (path, value1Hash, value2Hash) -> value2Hash
      oldHead = testBranchA.head
      head = testBranchA.merge ref: testBranchB, strategy: strategy
      assert.equal testBranchA.head, head
      diff = repo.diff oldHead, head
      for each in dataB
        for key, value of each
          assert.ok (diff.data[key] == value) or (diff.data[key] == undefined)
    it 'should merge branchA into branchB', () ->
      oldHead = testBranchB.head
      head = testBranchB.merge ref: dataAHashes[2]
      headTree = store.read head
      assert.equal _.difference(headTree.ancestors, [dataAHashes[2], oldHead]).length, 0
    it 'should merge branchA into branchC (they do not have a common commit)', () ->
      oldHead = testBranchC.head
      head = testBranchC.merge ref: dataAHashes[2]
      headTree = store.read head
      assert.equal _.difference(headTree.ancestors, [dataAHashes[2], oldHead]).length, 0
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

