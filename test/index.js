// Generated by CoffeeScript 1.3.3
(function() {
  var Repository, assert, async, commitB, commitC, dataA, dataAHashes, dataB, dataC, each, memoryStore, readDataHashs, readParents, repo, store, testBranchA, testBranchB, testBranchC, testBranchD, testData, _, _ref, _ref1;

  assert = require('assert');

  _ref = require('../lib/index'), Repository = _ref.Repository, memoryStore = _ref.memoryStore;

  async = require('async');

  _ = require('underscore');

  store = memoryStore();

  repo = new Repository(store);

  _ref1 = (function() {
    var _i, _len, _ref1, _results;
    _ref1 = [1, 2, 3, 4];
    _results = [];
    for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
      each = _ref1[_i];
      _results.push(repo.branch());
    }
    return _results;
  })(), testBranchA = _ref1[0], testBranchB = _ref1[1], testBranchC = _ref1[2], testBranchD = _ref1[3];

  testData = function(branch, data) {
    var path, value, _results;
    _results = [];
    for (path in data) {
      value = data[path];
      _results.push(assert.equal(branch.dataAtPath(path), value));
    }
    return _results;
  };

  readDataHashs = function(hashs, cb) {
    return async.map(hashs, (function(each, cb) {
      return repo.dataAtPathData(each, cb);
    }), cb);
  };

  readParents = function(treeHash, cb) {
    return repo.dataAtPathTree(treeHash, function(err, tree) {
      if (tree.ancestors.length === 0) {
        return cb(null, treeHash);
      } else {
        return async.map(tree.ancestors, readParents, function(err, res) {
          return cb(null, [treeHash, res]);
        });
      }
    });
  };

  dataA = [
    {
      'a': "hash1",
      'b/c': "hash2",
      'b/d': "hash3"
    }, {
      'a': "hash4",
      'b/c': "hash5",
      'b/e': "hash6",
      'b/f/g': "hash7"
    }, {
      'b/e': "hash8"
    }
  ];

  dataAHashes = ['9a3b879755108b450eddf5f035fdc149838f4bec', 'd19c7dccb948ed962794de79d002525e9b0c9f7f', 'bdd6e36bdec4c962cbbd21085cd77d85125693db'];

  dataB = [
    {
      'b/h': "hash9"
    }, {
      'c/a': "hash10"
    }, {
      'a': "hash11",
      'u': "hash12"
    }, {
      'b/c': "hash13",
      'b/e': "hash14",
      'b/f/a': "hash15"
    }
  ];

  dataC = [dataB[0], dataB[1]];

  commitB = {
    data: dataB,
    ref: dataAHashes[1],
    branch: testBranchB
  };

  commitC = {
    data: dataC,
    branch: testBranchC
  };

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
        testData(testBranchA, dataA[1]);
        d = testBranchA.dataAtPath('b/d');
        return assert.equal(d, dataA[0]['b/d']);
      });
      it('should read from a previous commit', function() {
        var eHead1, eHead2, head1, head2;
        head1 = testBranchA.head;
        head2 = testBranchA.commit(dataA[2]);
        eHead1 = repo.dataAtPath(head1, 'b/e');
        assert.equal(eHead1, dataA[1]['b/e']);
        eHead2 = repo.dataAtPath(head2, 'b/e');
        assert.equal(eHead2, dataA[2]['b/e']);
        eHead2 = testBranchA.dataAtPath('b/e');
        return assert.equal(eHead2, dataA[2]['b/e']);
      });
      return it('should populate more test branches', function() {
        var commitData, _i, _len, _ref2, _results;
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
        _ref2 = [commitB, commitC];
        _results = [];
        for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
          each = _ref2[_i];
          _results.push(commitData(each));
        }
        return _results;
      });
    });
    describe('commonCommit', function() {
      it('should find a common commit', function() {
        var res;
        res = testBranchA.commonCommit(testBranchB);
        return assert.equal(res, dataAHashes[1]);
      });
      return it('should not find a common commit', function() {
        var res;
        res = testBranchA.commonCommit(testBranchC);
        return assert.equal(res, void 0);
      });
    });
    describe('diff', function() {
      it('should find the diff between two trees', function() {
        var diff, hash, path, _i, _len, _ref2, _ref3;
        diff = repo.diff(dataAHashes[0], dataAHashes[1]);
        assert.equal(diff.data.length, _.keys(dataA[1]).length);
        _ref2 = diff.data;
        for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
          _ref3 = _ref2[_i], path = _ref3.path, hash = _ref3.hash;
          assert.equal(hash, dataA[1][path]);
        }
        return assert.equal(diff.trees.length, 3);
      });
      it('should find the diff between null and a tree', function() {
        var diff, hash, path, _i, _len, _ref2, _ref3, _results;
        diff = repo.diff(null, dataAHashes[0]);
        _ref2 = diff.data;
        _results = [];
        for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
          _ref3 = _ref2[_i], path = _ref3.path, hash = _ref3.hash;
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
    describe('patchHashs', function() {
      it('should find the diff as hashes between heads in the past and the current head', function() {
        var diff, realData;
        diff = testBranchA.patchHashs({
          from: dataAHashes[0]
        });
        realData = _.union(_.values(dataA[1]), _.values(dataA[2]));
        return assert.equal(_.intersection(diff.data, realData).length, realData.length);
      });
      it('should find the diff between a head in the past that doesnt exist and the current head', function() {
        var diff, realDataHashs;
        diff = testBranchA.patchHashs({
          from: null
        });
        realDataHashs = _.union(_.values(dataA[0]), _.values(dataA[1], _.values(dataA[2])));
        return assert.equal(_.intersection(diff.data, realDataHashs).length, realDataHashs.length);
      });
      return it('should work without a ref - returns the full diff', function() {
        var diff, realDataHashs;
        diff = testBranchA.patchHashs();
        realDataHashs = _.union(_.values(dataA[0]), _.values(dataA[1], _.values(dataA[2])));
        return assert.equal(_.intersection(diff.data, realDataHashs).length, realDataHashs.length);
      });
    });
    describe('patch', function() {
      return it('should find the diff including the actual trees between heads in the past and the current head', function() {
        var diff;
        diff = repo.patchData(testBranchA.patchHashs({
          from: dataAHashes[0]
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
        headTree = store.read(head);
        return assert.equal(_.difference(headTree.ancestors, [dataAHashes[2], oldHead]).length, 0);
      });
      return it('should merge branchA into branchC (they do not have a common commit)', function() {
        var head, headTree, oldHead;
        oldHead = testBranchC.head;
        head = testBranchC.merge({
          ref: dataAHashes[2]
        });
        headTree = store.read(head);
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
    return describe('treeAtPath', function() {
      it('should read the root tree', function() {
        var tree;
        tree = testBranchA.treeAtPath('');
        return assert.ok(tree.childData);
      });
      return it('should read a child tree', function() {
        var tree;
        tree = testBranchA.treeAtPath('b/f');
        return assert.equal(tree.childData.g, 'hash7');
      });
    });
  });

}).call(this);
