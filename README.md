#synclib
A peer-to-peer synchronized document store.

##Documentation
###new Repository() -> repository
Creates a new repository instance.

###repository.branch(ref) -> branch
Returns a new branch at the given ref.

###branch.commit(data, cb)
Commits the given data to the branch.

Data is expected like the following:

``` js
{
  'persons/jim': 'some value',
  'persons/ann': 'some other value'
}
```

###branch.dataAtPath(path, cb)
Responds with the stored data at the given part in the branch.

###branch.allPaths(cb)
Responds with a list of all paths in the branch.

###branch.commonCommit(ref, cb)
Responds with the common commit between the branch head and ref.

###branch.diff(ref, cb)
Responds with the data diff between the branch head and ref.

###branch.delta(ref, cb)
Responds with the full delta between the branch head and ref.
This includes the data of all intermediate commits.

###repository.applyDelta(delta, cb)
Writes the delta to the given repository.
This allows merging the delta using `branch.merge()`.

###branch.merge(ref, strategy, cb)
Should merge the branch head with ref using the given strategy.

A naive `strategy` could look like the following:

``` js
function strategy(path, value1Hash, value2Hash) {
  return value1Hash
}
```