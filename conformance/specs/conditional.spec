# Conditional reads

Tags: conditional

Checking a document without downloading it, and not re-downloading one
that hasn't changed.

* Connect as admin
* Create a fresh database

## Check a document without reading it
* Save document "a" with field "v" = "1"
* Remember the revision of document "a"
* Checking document "a" reports the remembered revision
* Checking document "zz" reports it is missing

## An unchanged document isn't sent again
* Save document "a" with field "v" = "1"
* Reading document "a" again with its ETag reports not modified
