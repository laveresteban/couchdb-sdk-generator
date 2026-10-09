# Mango queries

Tags: query

* Connect as admin
* Create a fresh database
* Bulk save documents with ages "20,30,40,50"

## Find with a selector
* Finding documents with age greater than "25" returns ages "30,40,50"

## Find using an index and sort
* Create a json index on field "age" named "age-idx"
* The index "age-idx" is listed
* Finding documents with age greater than "0" sorted descending returns ages "50,40,30,20"

## Paginate with limit and bookmark
* Finding documents with age greater than "0" with limit "2" returns "2" documents and a bookmark
* Continuing from the bookmark returns "2" more documents
