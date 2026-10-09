# Documents

Tags: documents

* Connect as admin
* Create a fresh database

## Create, read, update and delete a document
* Save document "doc1" with field "name" = "alice"
* Document "doc1" has field "name" = "alice"
* Update document "doc1" setting field "name" = "bob"
* Document "doc1" has field "name" = "bob"
* Document "doc1" has a revision starting with "2-"
* Delete document "doc1"
* Document "doc1" does not exist

## Writing with a stale revision is a conflict
* Save document "doc1" with field "n" = "1"
* Remember the revision of document "doc1"
* Update document "doc1" setting field "n" = "2"
* Saving document "doc1" with the remembered revision fails with status "409"

## Server-generated ids
* Create a document without an id with field "kind" = "auto"
* The created document can be read back with field "kind" = "auto"

## Bulk writes
* Bulk save "25" documents with field "type" = "bulk"
* The database has "25" documents
* All documents lists "25" rows
