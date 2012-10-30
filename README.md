#synclib
A distributed document store.

##So whats our architecture?

* Blob store: a content-addressable store for storing the data to be tracked
* Tree store: an in-memory store for storing all meta data for tracking
* Repository: an interface to commit, read, diff and merge - talks only to Tree store
* Replicator: an interface to manage replication of diffs across stores (Blob and Tree store)
