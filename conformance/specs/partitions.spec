# Partitioned databases

Tags: partitions

* Connect as admin

## Queries scoped to one partition
* Create a fresh partitioned database
* Save document "red:1" with field "color" = "red"
* Save document "red:2" with field "color" = "red"
* Save document "blue:1" with field "color" = "blue"
* All documents in partition "red" lists "2" rows
* Finding in partition "blue" for field "color" = "blue" returns "1" documents
