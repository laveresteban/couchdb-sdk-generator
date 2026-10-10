# Maintenance

Tags: maintenance

Housekeeping and diagnostics: compaction, index cleanup, purging, query
plans and multi-database info.

* Connect as admin
* Create a fresh database

## Compact a database
* Save document "a" with field "v" = "1"
* Compact the database
* Active tasks can be listed

## Clean up unused view indexes
* Clean up view indexes

## Purge removes a document without leaving a tombstone
* Save document "a" with field "v" = "1"
* Purge document "a"
* Document "a" does not exist
* The changes feed lists no documents

## Explain shows which index a query uses
* Bulk save documents with ages "20,30"
* Create a json index on field "age" named "age-idx"
* Explaining a query for age greater than "0" uses index "age-idx"

## Information about several databases at once
* Database info for this database and "no_such_database" finds "1" and misses "1"
