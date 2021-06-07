# GetRecordsInTextCollection
This Invocable Action mimics the built in Get Records element, and allows you to find records where a field matches one of a list of valid values.

## Inputs
* **objectName:** the object to search for
* **returnFields:** the list of fields to return, in a Text Collection variable (this will correspond to the list of fields after `SELECT` in a soql query) (if blank, will default to all accessible fields)
* **bindField:** the field on which we would like to filter our query (if blank, will default to `Id`)
* **validTextCollection:** a Text Collection of the valid values in the field **bindField**

## In short
This action will return records of **objectName** with the fields in **returnFields**, where the record's value in **bindField** is one of the values in **validTextCollection**. In SOQL this translates to `SELECT returnFields FROM objectName WHERE bindField IN :validTextCollection`.

## Bulkification
This action is bulkified. That means that if a flow runs on a batch of records (a record-edit flow or via process builder), the apex action will run once per batch of 200 records, and execute one SOQL per batch.

## Limitations
When this action runs on batches of records (see **Bulkification**), it does not support batches where different records request different **objectName**s. This is due to how the action is bulkified.

You may encounter an error when a flow tries to access a field which is null on a record. This is due to a limitation with dynamic soql not including null fields in its results. To avoid this issue, do not leave `returnFields` blank. The action will then check for null in those fields so that it can be properly returned to the flow.

## Feedback
Any and all feedback is welcome!
