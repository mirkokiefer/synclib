// Generated by CoffeeScript 1.3.3
(function() {
  var Repository, assert, async, commitB, commitC, commitD, contains, crossCheck, dataA, dataAHashes, dataB, dataBHashes, dataC, dataD, difference, each, keys, pluck, repo, testBranchA, testBranchB, testBranchC, testBranchD, testData, testTreeAncestors, union, values, _, _ref,
    __slice = [].slice;

  assert = require('assert');

  Repository = require('../lib/index').Repository;

  async = require('async');

  _ = require('underscore');

  union = _.union, difference = _.difference, keys = _.keys, values = _.values, pluck = _.pluck, contains = _.contains;

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

  crossCheck = function(array1, array2) {
    var _i, _j, _len, _len1, _results;
    for (_i = 0, _len = array2.length; _i < _len; _i++) {
      each = array2[_i];
      assert.ok(contains(array1, each));
    }
    _results = [];
    for (_j = 0, _len1 = array1.length; _j < _len1; _j++) {
      each = array1[_j];
      _results.push(assert.ok(contains(array2, each)));
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

  testTreeAncestors = function(treeHash, hashs) {
    var first, rest, tree;
    first = hashs[0], rest = 2 <= hashs.length ? __slice.call(hashs, 1) : [];
    assert.equal(treeHash, first);
    if (rest.length > 0) {
      tree = repo._treeStore.read(treeHash);
      return testTreeAncestors(tree.ancestors[0], rest);
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

  dataAHashes = ['e90eade66b9fc267016eff49d07bc5d8a64f0dda', '3f0f72434191cde81c71d26dc7db96bd03435feb', 'cca2949ddf3046f4956292e8623c731ea8c217d5'];

  dataBHashes = ['c6c3c788efd7d615887776c306290c45c29772cf', 'befd62c41818e1ea39573507fd1dc1cd47f01af3', '2fced862788cb4272f0d1d51869dba4d3552c630', '872a39296a6358c4d71c5de01aa0dc4c257718bf'];

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
        var head;
        head = testBranchA.commit(dataA[1]);
        return assert.equal(head, dataAHashes[1]);
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
        return testTreeAncestors(testBranchB.head, dataBHashes);
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
        var expectedTree1Path, expectedTree2Path, res1, res2;
        res1 = testBranchA.commonCommitWithPaths(testBranchB);
        expectedTree1Path = [dataAHashes[1], dataAHashes[2]];
        expectedTree2Path = dataBHashes.concat(dataAHashes[1]);
        crossCheck(res1.tree1Path, expectedTree1Path);
        crossCheck(res1.tree2Path, expectedTree2Path);
        res2 = testBranchA.commonCommitWithPaths(dataAHashes[0]);
        return assert.equal(res2.tree2Path.length, 1);
      });
      return it('should not find a common commit', function() {
        var res;
        res = testBranchA.commonCommit(testBranchC);
        return assert.equal(res, void 0);
      });
    });
    describe('diff', function() {
      it('should find the diff between two trees', function() {
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
      it('should find the diff between null and a tree', function() {
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
      return it('should find the diff between the current head and another tree', function() {
        var diff;
        diff = testBranchA.diff(testBranchB);
        return assert.ok(diff);
      });
    });
    describe('deltaHashs', function() {
      it('should find the diff as hashes between heads in the past and the current head', function() {
        var diff, realDataHashs;
        diff = testBranchA.deltaHashs({
          from: [dataAHashes[0]]
        });
        realDataHashs = _.union(_.values(dataA[1]), _.values(dataA[2]));
        return crossCheck(diff.data, realDataHashs);
      });
      it('should find the diff between a head in the past that doesnt exist and the current head', function() {
        var diff, realDataHashs;
        diff = testBranchA.deltaHashs({
          from: ['non-existing']
        });
        realDataHashs = _.union(_.values(dataA[0]), _.values(dataA[1]), _.values(dataA[2]));
        return crossCheck(diff.data, realDataHashs);
      });
      it('should work without a ref - returns the full diff', function() {
        var diff, realDataHashs;
        diff = testBranchA.deltaHashs();
        realDataHashs = _.union(_.values(dataA[0]), _.values(dataA[1]), _.values(dataA[2]));
        return crossCheck(diff.data, realDataHashs);
      });
      it('should compute the hash to a disconnected branch', function() {
        var diff, realDataHashs;
        diff = testBranchA.deltaHashs({
          to: [testBranchC]
        });
        realDataHashs = _.union(_.values(dataC[0]), _.values(dataC[1]));
        return crossCheck(diff.data, realDataHashs);
      });
      it('should compute the hash to multiple trees', function() {
        var diff, realDataHashs;
        diff = testBranchD.deltaHashs({
          to: [testBranchA, testBranchB]
        });
        realDataHashs = _.union(_.values(dataA[2]), _.values(dataB[3]));
        return crossCheck(diff.data, realDataHashs);
      });
      return it('should compute the delta from multiple trees to a single tree', function() {
        var diff, realDataHashs;
        diff = testBranchD.deltaHashs({
          from: [testBranchA, testBranchB, testBranchC]
        });
        realDataHashs = union(values(dataD[0]), values(dataD[1]));
        return crossCheck(diff.data, realDataHashs);
      });
    });
    describe('delta', function() {
      return it('should find the diff including the actual trees between heads in the past and the current head', function() {
        var diff;
        diff = repo.deltaData(testBranchA.deltaHashs({
          from: [dataAHashes[0]]
        }));
        assert.equal(diff.trees.length, 5);
        return assert.ok(diff.trees[0].length > 40);
      });
    });
    describe('merge', function() {
      it('should merge branchB into branchA', function() {
        var diff, head, key, oldHead, strategy, value, _i, _len, _results;
        strategy = function(path, value1Hash, value2Hash) {
          return value2Hash;
        };
        oldHead = testBranchA.head;
        head = testBranchA.merge({
          ref: testBranchB,
          strategy: strategy
        });
        assert.equal(testBranchA.head, head);
        diff = repo.diff(oldHead, head);
        _results = [];
        for (_i = 0, _len = dataB.length; _i < _len; _i++) {
          each = dataB[_i];
          _results.push((function() {
            var _results1;
            _results1 = [];
            for (key in each) {
              value = each[key];
              _results1.push(assert.ok((diff.data[key] === value) || (diff.data[key] === void 0)));
            }
            return _results1;
          })());
        }
        return _results;
      });
      it('should merge branchA into branchB', function() {
        var head, headTree, oldHead;
        oldHead = testBranchB.head;
        head = testBranchB.merge({
          ref: dataAHashes[2]
        });
        headTree = repo._treeStore.read(head);
        return assert.equal(_.difference(headTree.ancestors, [dataAHashes[2], oldHead]).length, 0);
      });
      return it('should merge branchA into branchC (they do not have a common commit)', function() {
        var head, headTree, oldHead;
        oldHead = testBranchC.head;
        head = testBranchC.merge({
          ref: dataAHashes[2]
        });
        headTree = repo._treeStore.read(head);
        return assert.equal(_.difference(headTree.ancestors, [dataAHashes[2], oldHead]).length, 0);
      });
    });
    describe('commit deletes', function() {
      return it('should delete data', function() {
        var data;
        data = {
          'b/c': null,
          'b/f/a': null,
          'b/f/g': null,
          'a': 1
        };
        testBranchB.commit(data);
        return testData(testBranchB, data);
      });
    });
    describe('treeAtPath', function() {
      it('should read the root tree', function() {
        var tree;
        tree = testBranchA.treeAtPath('');
        return assert.ok(tree.childData);
      });
      return it('should read a child tree', function() {
        var tree;
        tree = testBranchA.treeAtPath('b/f');
        return assert.equal(tree.childData.g, dataA[1]['b/f/g']);
      });
    });
    return describe('paths', function() {
      return it('should return all tracked paths', function() {
        var expectedPaths, paths, testBranch;
        testBranch = repo.branch(dataAHashes[0]);
        expectedPaths = keys(dataA[0]);
        paths = pluck(testBranch.allPaths(), 'path');
        assert.equal(difference(paths, expectedPaths).length, 0);
        return assert.equal(difference(expectedPaths, paths).length, 0);
      });
    });
  });

}).call(this);
