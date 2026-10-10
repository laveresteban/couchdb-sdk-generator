# Design documents and views

Tags: views

* Connect as admin
* Create a fresh database
* Bulk save documents with ages "20,30,40,50"

## Map/reduce view
* Save design document "stats" with view "by_age" emitting age and reducing with "_sum"
* Design document "stats" has view "by_age"
* Querying view "stats/by_age" without reduce returns "4" rows
* Querying view "stats/by_age" with reduce returns the value "140"

## Delete a design document
* Save design document "stats" with view "by_age" emitting age and reducing with "_count"
* Delete design document "stats"
* Design document "stats" does not exist

## Query a key range
* Save design document "stats" with view "by_age" emitting age and reducing with "_count"
* Querying view "stats/by_age" from key "25" to key "45" returns "2" rows
