
async = require 'async'
_ = require 'underscore'
{union, values, keys, intersection, clone} = _
{objectDiff, objectDiffObject, addKeyPrefix} = require './utils'
Branch = require './branch'

class Tree
  constructor: ({ancestors, childTrees, childData}={}) ->
    @ancestors = if ancestors then ancestors else []
    @childTrees = if childTrees then childTrees else {}
    @childData = if childData then childData else {}

splitCurrentAndChildTreeData = (data) ->
  currentTreeData = {}
  childTreeData = {}
  for {path, hash} in data
    key = path.pop()
    if path.length == 0 then currentTreeData[key] = hash
    else
      if not childTreeData[key] then childTreeData[key] = []
      childTreeData[key].push {path, hash}
  [currentTreeData, childTreeData]

commit = (treeHash, data, treeStore) ->
  currentTree = if treeHash
    tree = treeStore.read treeHash
    new Tree childData:clone(tree.childData), childTrees:clone(tree.childTrees), ancestors:[treeHash]
  else new Tree()
  [currentTreeData, childTreeData] = splitCurrentAndChildTreeData data
  for key, hash of currentTreeData
    if hash then currentTree.childData[key]=hash
    else delete currentTree.childData[key]
  for key, data of childTreeData
    previousTree = currentTree.childTrees[key]
    newChildTree = commit previousTree, data, treeStore
    if newChildTree then currentTree.childTrees[key] = newChildTree
    else delete currentTree.childTrees[key]
  if (_.size(currentTree.childTrees) > 0) or (_.size(currentTree.childData) > 0)
    treeStore.write currentTree

readTreeAtPath = (treeHash, treeStore, path) ->
  tree = treeStore.read treeHash
  if path.length == 0 then tree
  else
    key = path.pop()
    readTreeAtPath tree.childTrees[key], treeStore, path

read = (treeHash, treeStore, path) ->
  if not treeHash then undefined
  else
    tree = treeStore.read treeHash
    key = path.pop()
    if path.length == 0 then tree.childData[key]
    else read tree.childTrees[key], treeStore, path

treeParents = (treeHash, treeStore) -> treeStore.read(treeHash).ancestors
treesParents = (treeStore) -> (trees) -> _.flatten (treeParents each, treeStore for each in trees)

findCommonCommit = (trees1, trees2, treeStore) ->
  if (trees1.current.length == 0) and (trees2.current.length == 0) then return undefined
  for [trees1, trees2] in [[trees1, trees2], [trees2, trees1]]
    for each in trees1.current when _.contains trees2.visited.concat(trees2.current), each
      return each
  [trees1Parents, trees2Parents] = [trees1.current, trees2.current].map treesParents(treeStore)
  merge = (oldTrees, newParents) -> current: newParents, visited:oldTrees.visited.concat(oldTrees.current)
  findCommonCommit merge(trees1, trees1Parents), merge(trees2, trees2Parents), treeStore

findDiffWithPaths = (tree1Hash, tree2Hash, treeStore) ->
  if tree1Hash == tree2Hash then return trees: {}, data: {}
  [tree1, tree2] = for each in [tree1Hash, tree2Hash]
    if each then treeStore.read each else new Tree()
  diff = data: {}, trees: {}
  diff.trees = objectDiffObject tree1.childTrees, tree2.childTrees
  diff.data = objectDiffObject tree1.childData, tree2.childData
  mapChildTree = (diff, key) ->
    childDiff = findDiffWithPaths tree1.childTrees[key], tree2.childTrees[key], treeStore
    addKeyPrefix each, key+'/' for each in [childDiff.data, childDiff.trees]
    trees: _.extend(diff.trees, childDiff.trees), data: _.extend(diff.data, childDiff.data)
  _.keys(diff.trees).reduce mapChildTree, diff

findDiff = (tree1Hash, tree2Hash, store) ->
  res = findDiffWithPaths tree1Hash, tree2Hash, store
  trees: values(res.trees), data: values(res.data)

findDiffSince = (positions, oldTrees, treeStore) ->
  positions = _.difference positions, oldTrees
  oldTrees = _.difference oldTrees, positions
  if (oldTrees.length == 0) or (positions.length == 0) then return {trees: [], data: []}
  else
    mergeDiff = (diff, newDiff) ->
      trees: union(diff.trees, newDiff.trees), data: union(diff.data, newDiff.data)
    reduceFun = (diff, eachPosition) ->
      ancestors = treeParents eachPosition, treeStore
      if ancestors.length > 0
        parentDiffReduceFun = (diff, eachParent) ->
          mergeDiff diff, findDiff eachParent, eachPosition, treeStore
        diff = ancestors.reduce parentDiffReduceFun, diff
        mergeDiff diff, findDiffSince ancestors, oldTrees, treeStore
      else mergeDiff diff, findDiff(null, eachPosition, treeStore)
    positions.reduce reduceFun, {trees: [], data: []}

mergingCommit = (commonTreeHash, tree1Hash, tree2Hash, strategy, treeStore) ->
  conflict = (commonTreeHash != tree1Hash) and (commonTreeHash != tree2Hash)
  if not conflict then (if tree1Hash == commonTreeHash then tree2Hash else tree1Hash)
  else
    [commonTree, tree1, tree2] = (treeStore.read each for each in [commonTreeHash, tree1Hash, tree2Hash])
    commonTree = if commonTree then commonTree else new Tree()
    tree1 = if tree1 then tree1 else new Tree()
    tree2 = if tree2 then tree2 else new Tree()
    ancestors = (each for each in [tree1Hash, tree2Hash] when each)
    newTree = new Tree ancestors: ancestors
    mergeData = ->
      for key in union(keys(tree2.childData), keys(tree1.childData))
        commonData = commonTree.childData[key]; data1 = tree1.childData[key]; data2 = tree2.childData[key];
        conflict = (commonData != data1) and (commonData != data2)
        if conflict
          newTree.childData[key] = strategy key, data1, data2
        else
          newTree.childData[key] = if data1 == commonData then data2 else data1
    mergeChildTrees = ->
      for key in keys(tree2.childTrees)
        newTree.childTrees[key] = mergingCommit commonTree.childTrees[key], tree1.childTrees[key], tree2.childTrees[key], strategy, treeStore
    mergeData()
    mergeChildTrees()
    treeStore.write newTree

class Repository
  constructor: (@treeStore) ->
  branch: (treeHash) -> new Branch this, treeHash
  commit: (oldTree, data) ->
    parsedData = (path: path.split('/').reverse(), hash: hash for path, hash of data)
    commit oldTree, parsedData, @treeStore
  treeAtPath: (tree, path) ->
    path = if path == '' then [] else path.split('/').reverse()
    readTreeAtPath tree, @treeStore, path    
  dataAtPath: (tree, path) ->
    path = path.split('/').reverse()
    read tree, @treeStore, path
  commonCommit: (tree1, tree2) ->
    [trees1, trees2] = ({current: [each], visited: []} for each in [tree1, tree2])
    findCommonCommit trees1, trees2, @treeStore
  diff: (tree1, tree2) -> findDiffWithPaths tree1, tree2, @treeStore
  diffSince: (trees1, trees2) -> findDiffSince trees1, trees2, @treeStore
  merge: (tree1, tree2, strategy) ->
    obj = this
    commonTree = @commonCommit tree1, tree2
    if tree1 == commonTree then tree2
    else if tree2 == commonTree then tree1
    else
      mergingCommit commonTree, tree1, tree2, strategy, @treeStore

module.exports = Repository
