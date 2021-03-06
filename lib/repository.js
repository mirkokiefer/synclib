// Generated by CoffeeScript 1.3.3
(function() {
  var Branch, Commit, Queue, Repository, Store, Tree, addKeyPrefix, allPaths, async, clone, commit, commitAncestors, contains, contentAddressable, findCommonCommit, findCommonCommitWithPaths, findDelta, findDeltaDiff, findDiffWithPaths, findWalkPath, groupCurrentAndChildTreeData, intersection, keyValueStore, keys, mergeDiffs, mergingCommit, objectDiff, objectDiffObject, pairs, pluck, read, readCommitTree, readCommitTrees, readOrCreateNewTree, readOrCreateNewTrees, readTreeAtPath, union, values, _, _ref,
    __slice = [].slice;

  async = require('async');

  _ = require('underscore');

  union = _.union, values = _.values, keys = _.keys, intersection = _.intersection, clone = _.clone, contains = _.contains, pluck = _.pluck, pairs = _.pairs;

  _ref = require('./utils'), objectDiff = _ref.objectDiff, objectDiffObject = _ref.objectDiffObject, addKeyPrefix = _ref.addKeyPrefix, Queue = _ref.Queue;

  Branch = require('./branch');

  Store = require('./store');

  contentAddressable = require('content-addressable').memory;

  keyValueStore = require('pluggable-store').memory;

  Tree = (function() {

    function Tree(_arg) {
      var childData, childTrees, _ref1;
      _ref1 = _arg != null ? _arg : {}, childTrees = _ref1.childTrees, childData = _ref1.childData;
      this.childTrees = childTrees ? childTrees : {};
      this.childData = childData ? childData : {};
    }

    return Tree;

  })();

  Tree.serialize = function(obj) {
    var childData, childTrees, sort;
    sort = function(arr) {
      return arr.sort(function(a, b) {
        return a[0] > b[0];
      });
    };
    childTrees = sort(_.pairs(obj.childTrees));
    childData = sort(_.pairs(obj.childData));
    return JSON.stringify([childTrees, childData]);
  };

  Tree.deserialize = function(string) {
    var childData, childTrees, _ref1;
    _ref1 = JSON.parse(string), childTrees = _ref1[0], childData = _ref1[1];
    return new Tree({
      childTrees: _.object(childTrees),
      childData: _.object(childData)
    });
  };

  Commit = (function() {

    function Commit(_arg) {
      var ancestors, info, _ref1;
      _ref1 = _arg != null ? _arg : {}, ancestors = _ref1.ancestors, this.tree = _ref1.tree, info = _ref1.info;
      this.ancestors = ancestors ? ancestors : [];
      this.info = info ? info : [];
    }

    return Commit;

  })();

  Commit.serialize = function(obj) {
    return JSON.stringify([obj.ancestors.sort(), obj.tree, obj.info]);
  };

  Commit.deserialize = function(string) {
    var ancestors, info, tree, _ref1;
    _ref1 = JSON.parse(string), ancestors = _ref1[0], tree = _ref1[1], info = _ref1[2];
    return new Commit({
      ancestors: ancestors,
      tree: tree,
      info: info
    });
  };

  readOrCreateNewTree = function(treeStore) {
    return function(hash, cb) {
      if (hash) {
        return treeStore.read(hash, cb);
      } else {
        return cb(null, new Tree());
      }
    };
  };

  readOrCreateNewTrees = function(trees, treeStore, cb) {
    return async.map(trees, readOrCreateNewTree(treeStore), cb);
  };

  readCommitTree = function(commitStore) {
    return function(hash, cb) {
      if (!hash) {
        return cb(null);
      } else {
        return commitStore.read(hash, function(err, _arg) {
          var tree;
          tree = _arg.tree;
          return cb(null, tree);
        });
      }
    };
  };

  readCommitTrees = function(hashs, commitStore, cb) {
    return async.map(hashs, readCommitTree(commitStore), cb);
  };

  groupCurrentAndChildTreeData = function(data) {
    var childTreeData, currentTreeData, key, path, value, _i, _len, _ref1;
    currentTreeData = {};
    childTreeData = {};
    for (_i = 0, _len = data.length; _i < _len; _i++) {
      _ref1 = data[_i], path = _ref1.path, value = _ref1.value;
      key = path.pop();
      if (path.length === 0) {
        currentTreeData[key] = value;
      } else {
        if (!childTreeData[key]) {
          childTreeData[key] = [];
        }
        childTreeData[key].push({
          path: path,
          value: value
        });
      }
    }
    return [currentTreeData, childTreeData];
  };

  commit = function(treeHash, data, treeStore, cb) {
    if (data.length === 0) {
      return cb(null, treeHash);
    }
    return treeStore.read(treeHash, function(err, currentTree) {
      var childTreeData, currentTreeData, forEachChildTree, key, value, _ref1;
      if (!currentTree) {
        currentTree = new Tree();
      }
      _ref1 = groupCurrentAndChildTreeData(data), currentTreeData = _ref1[0], childTreeData = _ref1[1];
      for (key in currentTreeData) {
        value = currentTreeData[key];
        if (currentTree.childData[key] !== value) {
          if (value) {
            currentTree.childData[key] = value;
          } else {
            delete currentTree.childData[key];
          }
        }
      }
      forEachChildTree = function(_arg, cb) {
        var data, key, previousTree;
        key = _arg[0], data = _arg[1];
        previousTree = currentTree.childTrees[key];
        return commit(previousTree, data, treeStore, function(err, newChildTree) {
          if (newChildTree !== previousTree) {
            if (newChildTree) {
              currentTree.childTrees[key] = newChildTree;
            } else {
              delete currentTree.childTrees[key];
            }
          }
          return cb();
        });
      };
      return async.forEach(pairs(childTreeData), forEachChildTree, function() {
        if ((_.size(currentTree.childTrees) > 0) || (_.size(currentTree.childData) > 0)) {
          return treeStore.write(currentTree, cb);
        } else {
          return cb(null);
        }
      });
    });
  };

  readTreeAtPath = function(treeHash, treeStore, path, cb) {
    return treeStore.read(treeHash, function(err, tree) {
      var key;
      if (path.length === 0) {
        return cb(null, tree);
      } else {
        key = path.pop();
        return readTreeAtPath(tree.childTrees[key], treeStore, path, cb);
      }
    });
  };

  read = function(treeHash, treeStore, path, cb) {
    if (!treeHash) {
      return cb(null);
    } else {
      return treeStore.read(treeHash, function(err, tree) {
        var key;
        key = path.pop();
        if (path.length === 0) {
          return cb(null, tree.childData[key]);
        } else {
          return read(tree.childTrees[key], treeStore, path, cb);
        }
      });
    }
  };

  allPaths = function(treeHash, treeStore, cb) {
    return treeStore.read(treeHash, function(err, tree) {
      var findChildPaths, key, paths, value;
      paths = (function() {
        var _ref1, _results;
        _ref1 = tree.childData;
        _results = [];
        for (key in _ref1) {
          value = _ref1[key];
          _results.push({
            path: [key],
            value: value
          });
        }
        return _results;
      })();
      findChildPaths = function(paths, _arg, cb) {
        var childTree, key;
        key = _arg[0], childTree = _arg[1];
        return allPaths(childTree, treeStore, function(err, childPaths) {
          var path, res;
          res = (function() {
            var _i, _len, _ref1, _results;
            _results = [];
            for (_i = 0, _len = childPaths.length; _i < _len; _i++) {
              _ref1 = childPaths[_i], path = _ref1.path, value = _ref1.value;
              _results.push({
                path: [key].concat(__slice.call(path)),
                value: value
              });
            }
            return _results;
          })();
          return cb(null, paths.concat(res));
        });
      };
      return async.reduce(pairs(tree.childTrees), paths, findChildPaths, cb);
    });
  };

  commitAncestors = function(commitHash, commitStore, cb) {
    return commitStore.read(commitHash, function(err, commitObj) {
      if (commitObj) {
        return cb(null, commitObj.ancestors);
      } else {
        return cb(null, []);
      }
    });
  };

  findWalkPath = function(tree, visited) {
    var arr;
    arr = [tree];
    while ((tree = visited[tree])) {
      arr.push(tree);
    }
    return arr;
  };

  findCommonCommitWithPaths = function(commit1Start, commit2Start, commitStore, cb) {
    var condition, each, result, walkOneLevel, walker, walker1, walker2, _ref1;
    if ((!commit1Start) || (!commit2Start)) {
      return void 0;
    }
    _ref1 = (function() {
      var _i, _len, _ref1, _results;
      _ref1 = [commit1Start, commit2Start];
      _results = [];
      for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
        each = _ref1[_i];
        walker = {
          queue: new Queue,
          visited: {}
        };
        walker.queue.push(each);
        walker.visited[each] = null;
        _results.push(walker);
      }
      return _results;
    })(), walker1 = _ref1[0], walker2 = _ref1[1];
    result = null;
    walkOneLevel = function(cb) {
      var commit1, commit2, commitHash, pushAncestors, visited, _i, _len, _ref2, _ref3;
      commit1 = walker1.queue.pop();
      commit2 = walker2.queue.pop();
      _ref2 = [[commit1, walker2.visited], [commit2, walker1.visited]];
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        _ref3 = _ref2[_i], commitHash = _ref3[0], visited = _ref3[1];
        if (visited[commitHash] !== void 0) {
          result = {
            commit: commitHash,
            commit1Path: findWalkPath(commitHash, walker1.visited),
            commit2Path: findWalkPath(commitHash, walker2.visited)
          };
          return cb(null);
        }
      }
      pushAncestors = function(_arg, cb) {
        var commitHash, walker;
        commitHash = _arg[0], walker = _arg[1];
        return commitAncestors(commitHash, commitStore, function(err, ancestors) {
          var _j, _len1;
          for (_j = 0, _len1 = ancestors.length; _j < _len1; _j++) {
            each = ancestors[_j];
            walker.queue.push(each);
            if (!walker.visited[each]) {
              walker.visited[each] = commitHash;
            }
          }
          return cb();
        });
      };
      return async.forEach([[commit1, walker1], [commit2, walker2]], pushAncestors, cb);
    };
    condition = function() {
      return (result === null) && ((walker1.queue.length() > 0) || (walker2.queue.length() > 0));
    };
    return async.whilst(condition, walkOneLevel, function() {
      return cb(null, result);
    });
  };

  findCommonCommit = function(commit1, commit2, commitStore, cb) {
    return findCommonCommitWithPaths(commit1, commit2, commitStore, function(err, res) {
      if (res) {
        return cb(null, res.commit);
      } else {
        return cb(null);
      }
    });
  };

  findDiffWithPaths = function(tree1Hash, tree2Hash, treeStore, cb) {
    if (tree1Hash === tree2Hash) {
      return cb(null, {
        trees: [],
        values: []
      });
    }
    return readOrCreateNewTrees([tree1Hash, tree2Hash], treeStore, function(err, _arg) {
      var deletedData, diff, key, mapChildTree, tree1, tree2, updatedData, value;
      tree1 = _arg[0], tree2 = _arg[1];
      diff = {
        values: [],
        trees: [
          {
            path: [],
            value: tree2Hash ? tree2Hash : null
          }
        ]
      };
      updatedData = (function() {
        var _ref1, _results;
        _ref1 = tree2.childData;
        _results = [];
        for (key in _ref1) {
          value = _ref1[key];
          if (tree1.childData[key] !== value) {
            _results.push({
              path: [key],
              value: value
            });
          }
        }
        return _results;
      })();
      deletedData = (function() {
        var _results;
        _results = [];
        for (key in tree1.childData) {
          if (tree2.childData[key] === void 0) {
            _results.push({
              path: [key],
              value: null
            });
          }
        }
        return _results;
      })();
      diff.values = union(updatedData, deletedData);
      mapChildTree = function(diff, key, cb) {
        return findDiffWithPaths(tree1.childTrees[key], tree2.childTrees[key], treeStore, function(err, childDiff) {
          var prependPath;
          prependPath = function(pathHashs) {
            var path, _i, _len, _ref1, _results;
            _results = [];
            for (_i = 0, _len = pathHashs.length; _i < _len; _i++) {
              _ref1 = pathHashs[_i], path = _ref1.path, value = _ref1.value;
              _results.push({
                path: [key].concat(__slice.call(path)),
                value: value
              });
            }
            return _results;
          };
          return cb(null, {
            trees: union(diff.trees, prependPath(childDiff.trees)),
            values: union(diff.values, prependPath(childDiff.values))
          });
        });
      };
      return async.reduce(union(keys(tree1.childTrees), keys(tree2.childTrees)), diff, mapChildTree, cb);
    });
  };

  findDeltaDiff = function(tree1Hash, tree2Hash, treeStore, cb) {
    if (tree1Hash === tree2Hash) {
      return cb(null, {
        trees: [],
        values: []
      });
    }
    return readOrCreateNewTrees([tree1Hash, tree2Hash], treeStore, function(err, _arg) {
      var diff, key, mapChildTree, tree1, tree2, value;
      tree1 = _arg[0], tree2 = _arg[1];
      diff = {
        values: [],
        trees: tree2Hash ? [
          {
            hash: tree2Hash,
            data: tree2
          }
        ] : []
      };
      diff.values = (function() {
        var _ref1, _results;
        _ref1 = tree2.childData;
        _results = [];
        for (key in _ref1) {
          value = _ref1[key];
          if (tree1.childData[key] !== value) {
            _results.push(value);
          }
        }
        return _results;
      })();
      mapChildTree = function(diff, key, cb) {
        return findDeltaDiff(tree1.childTrees[key], tree2.childTrees[key], treeStore, function(err, childDiff) {
          return cb(null, {
            trees: union(diff.trees, childDiff.trees),
            values: union(diff.values, childDiff.values)
          });
        });
      };
      return async.reduce(union(keys(tree1.childTrees), keys(tree2.childTrees)), diff, mapChildTree, cb);
    });
  };

  mergeDiffs = function(oldDiff, newDiff) {
    if (!newDiff.commits) {
      newDiff.commits = [];
    }
    return {
      commits: union(oldDiff.commits, newDiff.commits),
      trees: union(oldDiff.trees, newDiff.trees),
      values: union(oldDiff.values, newDiff.values)
    };
  };

  findDelta = function(commonCommitHashs, toCommitHash, treeStore, commitStore, cb) {
    if (contains(commonCommitHashs, toCommitHash)) {
      return cb(null, {
        commits: [],
        trees: [],
        values: []
      });
    }
    return commitStore.read(toCommitHash, function(err, toCommit) {
      var diff, mapAncestorDiffs;
      diff = {
        commits: [
          {
            hash: toCommitHash,
            data: toCommit
          }
        ],
        trees: [],
        values: []
      };
      mapAncestorDiffs = function(ancestor, cb) {
        return commitStore.read(ancestor, function(err, _arg) {
          var tree;
          tree = _arg.tree;
          return findDeltaDiff(tree, toCommit.tree, treeStore, cb);
        });
      };
      return async.map(toCommit.ancestors, mapAncestorDiffs, function(err, ancestorDiffs) {
        var findIntersectingHashs, reduceFun;
        if (toCommit.ancestors.length === 1) {
          diff = mergeDiffs(diff, ancestorDiffs[0]);
          return findDelta(commonCommitHashs, toCommit.ancestors[0], treeStore, commitStore, function(err, ancestorDelta) {
            return cb(null, mergeDiffs(diff, ancestorDelta));
          });
        } else if (toCommit.ancestors.length === 0) {
          return findDeltaDiff(null, toCommit.tree, treeStore, function(err, deltaDiff) {
            return cb(null, mergeDiffs(diff, deltaDiff));
          });
        } else {
          findIntersectingHashs = function(hashObjects) {
            var each, intersectingHashs;
            intersectingHashs = intersection.apply(null, (function() {
              var _i, _len, _results;
              _results = [];
              for (_i = 0, _len = hashObjects.length; _i < _len; _i++) {
                each = hashObjects[_i];
                _results.push(pluck(each, 'hash'));
              }
              return _results;
            })());
            return union.apply(null, hashObjects).filter(function(each) {
              return contains(intersectingHashs, each.hash);
            });
          };
          diff = mergeDiffs(diff, {
            trees: findIntersectingHashs(pluck(ancestorDiffs, 'trees')),
            values: intersection.apply(null, pluck(ancestorDiffs, 'values'))
          });
          reduceFun = function(diff, ancestor, cb) {
            var mapCommonCommit;
            mapCommonCommit = function(each, cb) {
              return findCommonCommit(ancestor, each, treeStore, cb);
            };
            return async.map(commonCommitHashs, mapCommonCommit, function(err, newCommonTreeHashs) {
              return findDelta(union(newCommonTreeHashs), ancestor, treeStore, commitStore, function(err, ancestorDelta) {
                return cb(null, mergeDiffs(diff, ancestorDelta));
              });
            });
          };
          return async.reduce(toCommit.ancestors, diff, reduceFun, cb);
        }
      });
    });
  };

  mergingCommit = function(commonTreeHash, tree1Hash, tree2Hash, strategy, treeStore, cb) {
    var conflict;
    conflict = (commonTreeHash !== tree1Hash) && (commonTreeHash !== tree2Hash);
    if (!conflict) {
      if (tree1Hash === commonTreeHash) {
        return cb(null, tree2Hash);
      } else {
        return cb(null, tree1Hash);
      }
    } else {
      return readOrCreateNewTrees([commonTreeHash, tree1Hash, tree2Hash], treeStore, function(err, _arg) {
        var commonTree, mergeChildTrees, mergeData, newTree, tree1, tree2;
        commonTree = _arg[0], tree1 = _arg[1], tree2 = _arg[2];
        newTree = new Tree;
        mergeData = function() {
          var commonData, data1, data2, key, _i, _len, _ref1, _results;
          _ref1 = union(keys(tree2.childData), keys(tree1.childData));
          _results = [];
          for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
            key = _ref1[_i];
            commonData = commonTree.childData[key];
            data1 = tree1.childData[key];
            data2 = tree2.childData[key];
            conflict = (commonData !== data1) && (commonData !== data2);
            if (conflict) {
              _results.push(newTree.childData[key] = strategy(key, data1, data2));
            } else {
              _results.push(newTree.childData[key] = data1 === commonData ? data2 : data1);
            }
          }
          return _results;
        };
        mergeChildTrees = function(cb) {
          var mergeAtKey;
          mergeAtKey = function(key, cb) {
            return mergingCommit(commonTree.childTrees[key], tree1.childTrees[key], tree2.childTrees[key], strategy, treeStore, function(err, newChildTree) {
              newTree.childTrees[key] = newChildTree;
              return cb();
            });
          };
          return async.forEach(union(keys(tree2.childTrees), keys(tree1.childTrees)), mergeAtKey, cb);
        };
        mergeData();
        return mergeChildTrees(function() {
          return treeStore.write(newTree, cb);
        });
      });
    }
  };

  Repository = (function() {

    function Repository(_arg) {
      var _ref1;
      _ref1 = _arg != null ? _arg : {}, this.treeStore = _ref1.treeStore, this.commitStore = _ref1.commitStore;
      if (!this.treeStore) {
        this.treeStore = contentAddressable();
      }
      if (!this.commitStore) {
        this.commitStore = contentAddressable();
      }
      this._treeStore = new Store(this.treeStore, Tree);
      this._commitStore = new Store(this.commitStore, Commit);
    }

    Repository.prototype.branch = function(treeHash) {
      return new Branch(this, treeHash);
    };

    Repository.prototype.commit = function(oldCommitHash, data, cb) {
      var obj;
      obj = this;
      return this._commitStore.read(oldCommitHash, function(err, oldCommit) {
        var oldTree, parsedData, path, value;
        oldTree = oldCommit ? oldCommit.tree : void 0;
        parsedData = (function() {
          var _results;
          _results = [];
          for (path in data) {
            value = data[path];
            _results.push({
              path: path.split('/').reverse(),
              value: value
            });
          }
          return _results;
        })();
        return commit(oldTree, parsedData, obj._treeStore, function(err, newTree) {
          var ancestors, newCommit;
          if (newTree === oldTree) {
            return cb(null, oldCommitHash);
          } else {
            ancestors = oldCommitHash ? [oldCommitHash] : [];
            newCommit = new Commit({
              ancestors: ancestors,
              tree: newTree
            });
            return obj._commitStore.write(newCommit, cb);
          }
        });
      });
    };

    Repository.prototype.treeAtPath = function(commitHash, path, cb) {
      var obj;
      obj = this;
      path = path === '' ? [] : path.split('/').reverse();
      return this._commitStore.read(commitHash, function(err, _arg) {
        var tree;
        tree = _arg.tree;
        return readTreeAtPath(tree, obj._treeStore, path, cb);
      });
    };

    Repository.prototype.dataAtPath = function(commitHash, path, cb) {
      var obj;
      obj = this;
      path = path.split('/').reverse();
      return this._commitStore.read(commitHash, function(err, _arg) {
        var tree;
        tree = _arg.tree;
        return read(tree, obj._treeStore, path, cb);
      });
    };

    Repository.prototype.allPaths = function(commitHash, cb) {
      var obj;
      obj = this;
      if (commitHash) {
        return this._commitStore.read(commitHash, function(err, _arg) {
          var tree;
          tree = _arg.tree;
          return allPaths(tree, obj._treeStore, function(err, paths) {
            var path, value;
            return cb(null, (function() {
              var _i, _len, _ref1, _results;
              _results = [];
              for (_i = 0, _len = paths.length; _i < _len; _i++) {
                _ref1 = paths[_i], path = _ref1.path, value = _ref1.value;
                _results.push({
                  path: path.join('/'),
                  value: value
                });
              }
              return _results;
            })());
          });
        });
      } else {
        return cb(null, []);
      }
    };

    Repository.prototype.commonCommit = function(commit1, commit2, cb) {
      return findCommonCommit(commit1, commit2, this._commitStore, cb);
    };

    Repository.prototype.commonCommitWithPaths = function(commit1, commit2, cb) {
      return findCommonCommitWithPaths(commit1, commit2, this._commitStore, cb);
    };

    Repository.prototype.diff = function(commit1, commit2, cb) {
      var obj;
      obj = this;
      return readCommitTrees([commit1, commit2], obj._commitStore, function(err, _arg) {
        var tree1, tree2;
        tree1 = _arg[0], tree2 = _arg[1];
        return findDiffWithPaths(tree1, tree2, obj._treeStore, function(err, diff) {
          var translatePaths;
          translatePaths = function(array) {
            var path, value, _i, _len, _ref1, _results;
            _results = [];
            for (_i = 0, _len = array.length; _i < _len; _i++) {
              _ref1 = array[_i], path = _ref1.path, value = _ref1.value;
              _results.push({
                path: path.join('/'),
                value: value
              });
            }
            return _results;
          };
          return cb(null, {
            trees: translatePaths(diff.trees),
            values: translatePaths(diff.values)
          });
        });
      });
    };

    Repository.prototype.delta = function(_arg, cb) {
      var deltaForEach, diff, from, obj, to;
      from = _arg.from, to = _arg.to;
      obj = this;
      diff = {
        commits: [],
        trees: [],
        values: []
      };
      deltaForEach = function(diff, toEach, cb) {
        return async.map(from, (function(fromEach, cb) {
          return obj.commonCommit(fromEach, toEach, cb);
        }), function(err, commonCommits) {
          commonCommits = _.without(commonCommits, void 0);
          return findDelta(commonCommits, toEach, obj._treeStore, obj._commitStore, function(err, newDelta) {
            return cb(null, mergeDiffs(diff, newDelta));
          });
        });
      };
      return async.reduce(to, diff, deltaForEach, function(err, delta) {
        var serialize;
        serialize = function(objects) {
          var data, hash, _i, _len, _ref1, _results;
          _results = [];
          for (_i = 0, _len = objects.length; _i < _len; _i++) {
            _ref1 = objects[_i], hash = _ref1.hash, data = _ref1.data;
            _results.push({
              hash: hash,
              data: data.constructor.serialize(data)
            });
          }
          return _results;
        };
        return cb(null, {
          commits: serialize(delta.commits),
          trees: serialize(delta.trees),
          values: delta.values
        });
      });
    };

    Repository.prototype.applyDelta = function(delta, cb) {
      var obj;
      obj = this;
      return async.parallel([
        function(cb) {
          return obj.commitStore.writeAll(pluck(delta.commits, 'data'), cb);
        }, function(cb) {
          return obj.treeStore.writeAll(pluck(delta.trees, 'data'), cb);
        }
      ], cb);
    };

    Repository.prototype.merge = function(commit1, commit2, strategy, cb) {
      var obj;
      obj = this;
      if (!commit1) {
        return cb(null, commit2);
      }
      if (!commit2) {
        return cb(null, commit1);
      }
      strategy = strategy ? strategy : function(path, value1Hash, value2Hash) {
        return value1Hash;
      };
      return this.commonCommit(commit1, commit2, function(err, commonCommit) {
        if (commit1 === commonCommit) {
          return cb(null, commit2);
        } else if (commit2 === commonCommit) {
          return cb(null, commit1);
        } else {
          return readCommitTrees([commonCommit, commit1, commit2], obj._commitStore, function(err, _arg) {
            var commonTree, tree1, tree2;
            commonTree = _arg[0], tree1 = _arg[1], tree2 = _arg[2];
            return mergingCommit(commonTree, tree1, tree2, strategy, obj._treeStore, function(err, newTree) {
              return obj._commitStore.write(new Commit({
                ancestors: [commit1, commit2],
                tree: newTree
              }), cb);
            });
          });
        }
      });
    };

    return Repository;

  })();

  module.exports = Repository;

}).call(this);
