# Changes feed

Tags: changes

* Connect as admin
* Create a fresh database

## Normal feed reports every write
* Save document "a" with field "v" = "1"
* Save document "b" with field "v" = "1"
* The changes feed lists documents "a,b"

## Feed resumes from a sequence
* Save document "a" with field "v" = "1"
* Remember the current update sequence
* Save document "c" with field "v" = "1"
* The changes feed since the remembered sequence lists documents "c"

## Deletions appear in the feed
* Save document "a" with field "v" = "1"
* Delete document "a"
* The changes feed marks document "a" as deleted

## Feed filters by document ids
* Save document "a" with field "v" = "1"
* Save document "b" with field "v" = "1"
* The changes feed filtered to documents "b" lists documents "b"

## Reader resumes from its checkpoint
* Save document "a" with field "v" = "1"
* Follow the changes feed with checkpoint "reader" until document "a"
* Save document "c" with field "v" = "1"
* Following the changes feed with checkpoint "reader" next yields document "c"
