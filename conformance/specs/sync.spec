# Sync primitives

Tags: sync

The pieces an offline replicator is built from: revision diffs, bulk
fetches with history, local checkpoints, writes that keep the caller's
revision ids, and filtered changes.

* Connect as admin
* Create a fresh database

## Revs diff reports only revisions the database lacks
* Save document "a" with field "v" = "1"
* Remember the revision of document "a"
* Revs diff for document "a" with the remembered revision reports nothing missing
* Revs diff for document "a" with revision "9-deadbeef" reports "9-deadbeef" missing

## Bulk get returns documents with their revision history
* Save document "a" with field "v" = "1"
* Update document "a" setting field "v" = "2"
* Save document "b" with field "v" = "1"
* Bulk get documents "a,b" with history returns "2" documents
* Bulk get history of document "a" lists "2" revisions
* Bulk get of missing document "zz" reports "not_found"

## Local documents store checkpoints outside replication
* Save local document "checkpoint" with field "last_seq" = "5"
* Local document "checkpoint" has field "last_seq" = "5"
* All documents lists "0" rows
* The changes feed lists no documents
* Delete local document "checkpoint"
* Local document "checkpoint" does not exist

## Writing without new edits keeps the given revision
* Write document "x" at revision "1-aaa" with field "v" = "1" without new edits
* Document "x" has a revision starting with "1-aaa"

## Concurrent branches become conflicts
* Write document "x" at revision "1-aaa" with field "v" = "1" without new edits
* Write document "x" at revision "1-bbb" with field "v" = "2" without new edits
* Document "x" has a revision starting with "1-bbb"
* Document "x" has "1" conflicts
* The changes feed with all leaf revisions lists "2" revisions for document "x"

## Document revision history
* Save document "a" with field "v" = "1"
* Update document "a" setting field "v" = "2"
* Update document "a" setting field "v" = "3"
* Document "a" with revision history lists "3" revisions

## Changes filtered by document ids
* Save document "a" with field "v" = "1"
* Save document "b" with field "v" = "1"
* Save document "c" with field "v" = "1"
* The changes feed filtered to documents "a,c" lists documents "a,c"

## Changes filtered by selector
* Save document "a" with field "owner" = "alice"
* Save document "b" with field "owner" = "bob"
* The changes feed filtered by field "owner" = "alice" lists documents "a"
