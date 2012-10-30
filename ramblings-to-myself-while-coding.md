#NodeStore
A distributed document store.

Done:
* be able to find the diff between two trees
* be able to find the diff between two commits
* be able to find the common parent of multiple commits
* be able to merge two commits

Todo:
* useful tools and interfaces...

##How do network transfers work?
Ok what has to be sent between repos?

Repo 1, Repo 2

Case 1: Repo 2 is ahead of Repo 1 by a few commits

Repo 2 starts sync:
Send Repo 1 its current head(s)
Repo 1 searches common commit - can't find one --> replies with his head(s)
Repo 2 searches common commit with Repo 1's head
Finds common commit --> is up to date

Repo 1 starts sync:
Send Repo 2 its current head
Repo 2 finds common commit
Repo 2 replies with a full diff since the common commit and its current head
Repo 1 does a local merge

Case 2: Repo 2 has no common commits with Repo 1

Repo 2 starts sync:
Send Repo 1 current head
Repo 1 finds no common commit --> replies with his head
Repo 2 finds no common commit
Repo 2 asks Repo 1 for full diff
Repo 2 does a local merge

So if a common commit is found a diff can be given immediately.
If no common commit is found we first need to find out if they have never been synced before.

A sends B head
  common commit found: reply with diff and head -> merge
  no common commit: reply with head
    A finds common commit: no merge needed (A is ahead of B)
    A no common commit found: ask for full diff -> merge

Could we model this with Resources?

a diff:
GET repo1/diff?tree1=repo1Head&tree2=head
a full diff:
GET repo1/diff?tree1=null&tree2=head
adding trees:
POST repo1/trees
adding data:
POST repo1/data
get trees:
GET repo1/trees/asadfasdf809 (or head)
trees include hyperlinks to children and parents

I really have to change the terminology - parents are not parent nodes but rather the previous version of a tree node.

How do we do delta compression when transferring diffs?
Shouldnt it be done on the fly while finding the diff?
No it cant - the diff doesnt touch the data at all... Its only sees hashes.
So the trees probably dont have to be compressed at all. Its really the data that counts.
And thats trivial - just delta compress using each previous tree's data.
Ok but thats really an optimization that can differ a lot depending on the tracked data.
Delta compression is great for text but useless for other kinds of data.
So what we really need is a compression interface. My thesis is that for most compression algos you just need the previous and the current data. Some may even only need the current data.

What are options for data transfer?
* email - simple, scalable
* http server - easy to do in node
* zmq - probably the cleanest solution
* iOS push notifications??
* Amazon SQS??
I'd like to have something that doesnt require much infrastructure on my own.
So whats basically needed is a scalable message queue that pushes the data to all peers.
Interesting could be a hybrid solution where you use a different transport mechanism for meta data than for the actual data.
The actual data could be stored in S3. All meta data could be pushed using a message queue.
I really have to check some of the messaging stuff in iOS and Android.

Building a http interface:
Client POSTs data to /data
-> returns the retrieval URL like: /data/somehash
Client POSTs paths to /tree/branchname
-> returns URL to new tree /tree/somehash

GET /tree/somehash
should return tree with direct children (tree and data hashs)

No, this is the wrong way to do this. The server shouldnt be seen as the repo to commit to.
You commit locally inside your browser and push changes to the server.
So the server interface is very simple:
GET /common-tree?mytree=somehash
returns a common tree if exists
the client then identifies the diff to send
POST /data with the raw data as a JSON array
POST /tree with all trees
PUT /remote/myremoteid with my local head hash
We dont actually tell the server to merge - we just give it all our data and notify it about our head.
Depending on the server's setup he may then decide to merge my changes on a certain branch.

It works the other way around as well.
We can ask the server about his current head:
GET /branch/branchname
We search for a common commit locally
GET /diff?from=common&to=servershead

Well actually I'm just thinking we dont need the server to do any merges at all. We do all merges locally and really just push trees to the server.
Then we just PUT a branch name on the server to the latest tree hash. Or even better just like in the example above - every remote just puts *its* own head under /remote/remoteid.
Other clients can then manually merge each of the remotes as they wish.
So the server is really just a simple key-value store - CouchDB would suit it perfectly.
Ok not quite - right now the server still has to compute common tree and diffs.
Well that could change - its actually something the clients could do as well.
So whenever a client updates his head he also computes the diff for each remote thats registered on the server.
He could put the result on a resource like this: /diff/from=hash1&to=hash2
If for some reason a needed diff isnt precomputed the client could do this manually by retrieving each tree:
GET /tree/hash
This should just work out of the box by plugging a http based backend into the lib and calling store.diff!!
We could even write a backend that "caches" all retrieved trees in the local store as well.
Ok cool, so we really just need some high-level client APIs to manage all of this transparently.
Lets just use CouchDB for testing.
This could become a serious framework for doing next gen offline apps.
To make this popular we need:
* pluggable backends: CouchDD, DynamoDB, Redis, ...
* a great sample app (collaborative document store)
* mobile client implementations (PhoneGap, Sencha, iOS, Android)
* security patterns - how to restrict access to certain folders etc.
* conflict resolution strategies (especially for text)

A see a big chance in providing tracking of subtrees - it could mean that a large number of apps could be tracked in the same store without them having to know about it. Each app just needs a subfolder to work on.

Also the pattern of not letting the clients communicate peer-to-peer but rather have a dumb key-value store in between is great. Really similar to what CouchDB was supposed to become - except they didnt have the client libs.

Ok, get real what are the next steps:
Lets build a simple project management app
* Projects
* Tasks per Project
* Discussions per Project
be able to mention tasks in discussions.
Everything is stored locally.
When does syncing get triggered?
On every change? Well yes on every change in the UI - which could be multiple changes in the store.
This should be super fancy - I want websockets and everything. So live collaboration.
We should then have the ability to replay all changes - this demonstrates the history feature.
That would actually be a unique differentiator to any other project collaboration app.
Anyone new to a project could replay the history and become immediately familiar with how and why decisions were made.
This would eliminate the need to have an "archive" of old tasks and discussions - at any time you only see the current stuff. Its cool to know that you can delete anything thats on the screen if you dont need it at the moment.
A search could then bring up an old discussion which would then be immediately next to the state of the project at that time (other discussions, tasks, calendar).

Ok realistically we cant assume to be able to store everything in the browser.
So we will most likely have to use a lazy retrieval mechanism - local first, then server.
But the architecture stays the same - you see the browser as a local store that gets synced with the server.

We really need a way to clean the offline store as its limited to 5mb.
The best way is probably to recurse through all current data, maybe a few commits back - and just delete the rest.

I just seriously thought through the crazy idea of using IMAP and SMTP for syncing.
There is a huge amount of existing, cheap infrastructure for email. Maybe this could be leveraged for distributed apps.
For every commit the app could send mails for the diff. For example a mail per data object (using the hash as the subject) and a mail for all tree data. Another mail could be sent to notify the peer of the current head tree.
The peer app would then check mails using IMAP and read all tree data in its store. Then it does the merge and lazily retrieves all data objects. IMAP is really perfectly suited for that.
I just wonder what the performance of all this is - but I mean email is pretty fast...

I could use this timeline to display history:
http://timeline.verite.co/

I should strictly separate the hash tracking and storage interfaces.
The lib should actually be a pure hash tracker - it doesnt care about the data and should never touch it.
So all interfaces deal purely with hashes.
Ok so the lib only stores the tree data itself. Well, this should be reasonably small - so should we keep it all in memory by design?? This would remove all callbacks...
I actually think yes!
The only thing that should be async is pushing and fetching of data across stores.

So whats our architecture? :
Blob store: a content-addressable store for storing the data to be tracked
Tree store: an in-memory store for storing all tree data
Tracker: an interface to commit, read, diff and merge - talks only to Tree store
Replicator: an interface to manage replication of diffs across stores (Blob and Tree store)

The Replicator:
Is this really just a mechanism to send diffs to other stores?
We somehow need to retrieve branch heads as well!
I kind of see the Blob store behave like a REST store - just PUTs and GETs of data.
We probably don't replicate its entire content - clients might just selectively retrieve relevant data.
The Tree store is different - it really pushes or fetches entire diffs at once.
But these replication mechanisms are really not the core of the lib. CouchDB for example could do the replication just fine!
I might still think of implementing interfaces for certain replication patterns.

Thinking about forgetting history:
Most apps dont really care about keeping the entire change history - it might in fact even be a burden.
I don't really see a problem in deleting history.
We only need to be sure that all remotes are already past the deleted history.
How do we figure out what can be deleted? Its basically mark and sweep garbage collection...

