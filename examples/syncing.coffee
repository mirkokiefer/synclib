_ = require 'underscore'
{keys, values, object} = _
async = require 'async'
{Repository, TreeStore, backend} = require '../lib/index'
FileStore = new backend.server.FileSystem

# create two physical stores:
home = process.env.HOME
storeA = new FileStore home+'/storeA'
storeB = new FileStore home+'/storeB'

# create two in-memory stores for all tracking data:
treeStoreA = new TreeStore
treeStoreB = new TreeStore

# create two Repos to track data changes to the stores:
repoA = new Repository treeStoreA
repoB = new Repository treeStoreB

# commit some data (path-value objects)
json = JSON.stringify
storeData = (store, repo) -> (data, cb) ->
  # persist the actual data to the store - only remember their hashes
  async.map values(dataAa), store.write, (err, hashs) ->
    # put together the path-hash object
    dataHashs = object keys(data), hashs
    # commit the hash data to the repository
    repo.commit dataHashs

commitDataToRepoA = (cb) ->
  dataA1 =
    'users/mirko': json name: 'Mirko', location: 'Heidelberg, Germany'
    'users/haykuhi': json name: 'Haykuhi', location: 'Mörlenbach, Germany'
    'todos/1': json task: 'create synclib examples', assignee: 'users/mirko'
    'todos/2': json task: 'make food', assignee: 'users/mirko'
  dataA2 =
    'users/mirko': json name: 'Mirko', location: 'Berlin, Germany'
    'todos/2': json task: 'make delicious food', assignee: 'users/mirko'
    'todos/3': json task: 'sleep'
  dataA3 =
    'todos/3': null

  async.forEach [dataA1, dataA2, dataA3], storeData(storeA, repoA), cb

pushToRepoB = (cb) ->
  patch = repoA.patchSince [null]
  