// Generated by CoffeeScript 1.3.3
(function() {
  var Repository, assert, assertArray, assertPathData, async, commitB, commitC, commitD, contains, dataA, dataAHashes, dataB, dataBHashes, dataC, dataD, difference, each, keys, pluck, repo, testBranchA, testBranchB, testBranchC, testBranchD, testCommitAncestors, testData, union, values, where, _, _ref,
    __slice = [].slice;

  assert = require('assert');

  Repository = require('../lib/index').Repository;

  async = require('async');

  _ = require('underscore');

  union = _.union, difference = _.difference, keys = _.keys, values = _.values, pluck = _.pluck, contains = _.contains, where = _.where;

  repo = new Repository();

  _ref = (function() {
    var _i, _len, _ref, _results;
    _ref = ['a', 'b', 'c', 'd'];
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      each = _ref[_i];
      _results.push(repo.branch());
    }
    return _results;
  })(), testBranchA = _ref[0], testBranchB = _ref[1], testBranchC = _ref[2], testBranchD = _ref[3];

  assertArray = function(array, expectedArray) {
    var _i, _j, _len, _len1, _results;
    for (_i = 0, _len = expectedArray.length; _i < _len; _i++) {
      each = expectedArray[_i];
      assert.ok(contains(array, each));
    }
    _results = [];
    for (_j = 0, _len1 = array.length; _j < _len1; _j++) {
      each = array[_j];
      _results.push(assert.ok(contains(expectedArray, each)));
    }
    return _results;
  };

  assertPathData = function(data, expected) {
    var found, path, value, _i, _len, _ref1, _results;
    assert.equal(data.length, expected.length);
    _results = [];
    for (_i = 0, _len = expected.length; _i < _len; _i++) {
      _ref1 = expected[_i], path = _ref1.path, value = _ref1.value;
      found = where(data, {
        path: path
      });
      assert.equal(found.length, 1);
      _results.push(assert.equal(found[0].value, value));
    }
    return _results;
  };

  testData = function(branch, data) {
    var path, value, _results;
    _results = [];
    for (path in data) {
      value = data[path];
      _results.push(assert.equal(branch.dataAtPath(path), value));
    }
    return _results;
  };

  testCommitAncestors = function(commitHash, hashs) {
    var ancestors, first, rest;
    first = hashs[0], rest = 2 <= hashs.length ? __slice.call(hashs, 1) : [];
    assert.equal(commitHash, first);
    if (rest.length > 0) {
      ancestors = repo._commitStore.read(commitHash).ancestors;
      return testCommitAncestors(ancestors[0], rest);
    }
  };

  dataA = [
    {
      'a': "hashA 0.0",
      'b/c': "hashA 0.1",
      'b/d': "hashA 0.2"
    }, {
      'a': "hashA 1.0",
      'b/c': "hashA 1.1",
      'b/e': "hashA 1.2",
      'b/f/g': "hashA 1.3"
    }, {
      'b/e': "hashA 2.0"
    }
  ];

  dataB = [
    {
      'b/h': "hashB 0.0"
    }, {
      'c/a': "hashB 1.0"
    }, {
      'a': "hashB 2.0",
      'u': "hashB 2.1"
    }, {
      'b/c': "hashB 3.0",
      'b/e': "hashB 3.1",
      'b/f/a': "hashB 3.2"
    }
  ];

  dataC = [
    {
      'a': 'hashC 0.0',
      'c/a': 'hashC 0.1'
    }, {
      'a': 'hashC 1.0'
    }
  ];

  dataD = [
    {
      'e': 'hashD 0.0'
    }, {
      'b/f/b': 'hashD 1.0'
    }
  ];

  dataAHashes = ['b2ef9fc4cb736db036b5dc098f1054546bcaf1be', '5bc500f2e12c1cf10719925cf1848413965603ff', '7693e2f18011f0a995e26880f17230fd36f04c5d'];

  dataBHashes = ['fca94cfa923725e3c6318bb5eef14dffd9c38091', 'ae1287e2835cfea8fca7a880dcfe09ecf4dfb428', 'c3015798e734dc9bbc3e8fc58e677e2eacc1a377', '68d1f53596baa4bdc69208a06538e88d9612e77a'];

  commitB = {
    data: dataB,
    ref: dataAHashes[1],
    branch: testBranchB
  };

  commitC = {
    data: dataC,
    branch: testBranchC
  };

  commitD = {
    data: dataD,
    ref: dataBHashes[1],
    branch: testBranchD
  };

  /*
  a graphical branch view:
  
                      d0 - d1 <- D
                    /
            b0 - b1 - b2 - b3 <- B
          /
  a0 - a1 - a2 <- A
  
  c0 - c1 <- C
  */


  describe('branch', function() {
    describe('commit', function() {
      it('should commit and read objects', function() {
        var head;
        head = testBranchA.commit(dataA[0]);
        assert.equal(head, dataAHashes[0]);
        return testData(testBranchA, dataA[0]);
      });
      it('should create a child commit', function() {
        var d, head;
        head = testBranchA.commit(dataA[1]);
        assert.equal(head, dataAHashes[1]);
        testData(testBranchA, dataA[1]);
        d = testBranchA.dataAtPath('b/d');
        return assert.equal(d, dataA[0]['b/d']);
      });
      it('should not create a new commit', function() {
        var head, oldHead;
        oldHead = testBranchA.head;
        head = testBranchA.commit(dataA[1]);
        return assert.equal(head, oldHead);
      });
      it('should read from a previous commit', function() {
        var eHead1, eHead2, head1, head2;
        head1 = testBranchA.head;
        head2 = testBranchA.commit(dataA[2]);
        assert.equal(head2, dataAHashes[2]);
        eHead1 = repo.dataAtPath(head1, 'b/e');
        assert.equal(eHead1, dataA[1]['b/e']);
        eHead2 = repo.dataAtPath(head2, 'b/e');
        assert.equal(eHead2, dataA[2]['b/e']);
        eHead2 = testBranchA.dataAtPath('b/e');
        return assert.equal(eHead2, dataA[2]['b/e']);
      });
      return it('should populate more test branches', function() {
        var commitData, _i, _len, _ref1;
        commitData = function(_arg) {
          var branch, data, ref, _i, _len, _results;
          branch = _arg.branch, data = _arg.data, ref = _arg.ref;
          branch.head = ref;
          _results = [];
          for (_i = 0, _len = data.length; _i < _len; _i++) {
            each = data[_i];
            _results.push(branch.commit(each));
          }
          return _results;
        };
        _ref1 = [commitB, commitC, commitD];
        for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
          each = _ref1[_i];
          commitData(each);
        }
        return testCommitAncestors(testBranchB.head, dataBHashes);
      });
    });
    describe('commonCommit', function() {
      it('should find a common commit', function() {
        var res1, res2, res3, res4, res5;
        res1 = testBranchA.commonCommit(testBranchB);
        assert.equal(res1, dataAHashes[1]);
        res2 = testBranchA.commonCommit(testBranchD);
        assert.equal(res2, dataAHashes[1]);
        res3 = testBranchA.commonCommit(dataAHashes[0]);
        assert.equal(res3, dataAHashes[0]);
        res4 = repo.commonCommit(dataAHashes[2], dataAHashes[0]);
        assert.equal(res4, dataAHashes[0]);
        res5 = repo.commonCommit(dataAHashes[0], dataAHashes[2]);
        return assert.equal(res5, dataAHashes[0]);
      });
      it('should find a common commit with paths', function() {
        var expectedCommit1Path, expectedCommit2Path, res1, res2;
        res1 = testBranchA.commonCommitWithPaths(testBranchB);
        expectedCommit1Path = [dataAHashes[1], dataAHashes[2]];
        expectedCommit2Path = dataBHashes.concat(dataAHashes[1]);
        assertArray(res1.commit1Path, expectedCommit1Path);
        assertArray(res1.commit2Path, expectedCommit2Path);
        res2 = testBranchA.commonCommitWithPaths(dataAHashes[0]);
        return assert.equal(res2.commit2Path.length, 1);
      });
      return it('should not find a common commit', function() {
        var res;
        res = testBranchA.commonCommit(testBranchC);
        return assert.equal(res, void 0);
      });
    });
    return describe('diff', function() {
      it('should find the diff between two commits', function() {
        var diff, hash, path, _i, _len, _ref1, _ref2;
        diff = repo.diff(dataAHashes[0], dataAHashes[1]);
        assert.equal(diff.data.length, _.keys(dataA[1]).length);
        _ref1 = diff.data;
        for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
          _ref2 = _ref1[_i], path = _ref2.path, hash = _ref2.hash;
          assert.equal(hash, dataA[1][path]);
        }
        return assert.equal(diff.trees.length, 3);
      });
      it('should find the diff between null and a commit', function() {
        var diff, hash, path, _i, _len, _ref1, _ref2, _results;
        diff = repo.diff(null, dataAHashes[0]);
        _ref1 = diff.data;
        _results = [];
        for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
          _ref2 = _ref1[_i], path = _ref2.path, hash = _ref2.hash;
          _results.push(assert.equal(hash, dataA[0][path]));
        }
        return _results;
      });
      return it('should find the diff between the current head and another commit', function() {
        var diff;
        diff = testBranchA.diff(testBranchB);
        return assert.ok(diff);
      });
    });
    /*describe 'deltaHashs', () ->
      it 'should find the diff as hashes between heads in the past and the current head', () ->
        diff = testBranchA.deltaHashs from: [dataAHashes[0]]
        realDataHashs = _.union(_.values(dataA[1]), _.values(dataA[2]))
        assertArray diff.data, realDataHashs
      it 'should find the diff between a head in the past that doesnt exist and the current head', () ->
        diff = testBranchA.deltaHashs from: ['non-existing']
        realDataHashs = _.union _.values(dataA[0]), _.values(dataA[1]), _.values(dataA[2])
        assertArray diff.data, realDataHashs
      it 'should work without a ref - returns the full diff', () ->
        diff = testBranchA.deltaHashs()
        realDataHashs = _.union _.values(dataA[0]), _.values(dataA[1]), _.values(dataA[2])
        assertArray diff.data, realDataHashs
      it 'should compute the hash to a disconnected branch', ->
        diff = testBranchA.deltaHashs to: [testBranchC]
        realDataHashs = _.union _.values(dataC[0]), _.values(dataC[1])
        assertArray diff.data, realDataHashs
      it 'should compute the hash to multiple trees', ->
        diff = testBranchD.deltaHashs to: [testBranchA, testBranchB]
        realDataHashs = _.union _.values(dataA[2]), _.values(dataB[3])
        assertArray diff.data, realDataHashs
      it 'should compute the delta from multiple trees to a single tree', ->
        diff = testBranchD.deltaHashs from: [testBranchA, testBranchB, testBranchC]
        realDataHashs = union values(dataD[0]), values(dataD[1])
        assertArray diff.data, realDataHashs
    describe 'delta', () ->
      it 'should find the diff including the actual trees between heads in the past and the current head', () ->
        diff = repo.deltaData testBranchA.deltaHashs from: [dataAHashes[0]]
        assert.equal diff.trees.length, 5
        assert.ok diff.trees[0].length > 40
    describe 'merge', () ->
      assertMerge = (branch, expectedData, expectedHeads) ->
        headTree = repo._treeStore.read branch.head
        assertArray headTree.ancestors, expectedHeads
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
    */

  });

}).call(this);
