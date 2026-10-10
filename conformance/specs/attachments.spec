# Attachments

Tags: attachments

* Connect as admin
* Create a fresh database

## Upload, download and delete an attachment
* Save document "doc1" with field "name" = "with-file"
* Attach "hello couchdb" as "greeting.txt" to document "doc1"
* Attachment "greeting.txt" of document "doc1" contains "hello couchdb"
* Document "doc1" lists attachment "greeting.txt"
* Delete attachment "greeting.txt" from document "doc1"
* Attachment "greeting.txt" of document "doc1" does not exist

## Attachment keeps its content type
* Save document "doc1" with field "name" = "typed"
* Attach "<p>hi</p>" as "page.html" with content type "text/html" to document "doc1"
* Attachment "page.html" of document "doc1" has content type "text/html"
