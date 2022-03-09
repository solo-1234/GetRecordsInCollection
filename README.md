# GetRecordsInCollection
This Invocable Action mimics the built in Get Records element, and allows you to find records where a field matches one of a list of valid values.

Note: The GetRecordsInTextCollection class has been replaced with GetRecordsInCollection which allows you to either pass in a list of valid values to search for, OR a record collection and a field name if you'd like to search for any of the values in that field for all the records in the collection.

## Inputs
* **objectName:** the object to search for
* **returnFields:** the list of fields to return, in a Text Collection variable (this will correspond to the list of fields after `SELECT` in a soql query) (if blank, will default to all accessible fields)
* **bindField:** the field on which we would like to filter our query (if blank, will default to `Id`)
* **validTextCollection:** a Text Collection of the valid values in the field **bindField** (optional, if you omit this you may instead use the next two inputs)
* **sourceRecordCollection:** a Record Collection (of any object type) to use for determining the valid values (also see **sourceFieldToMatch**)
* **sourceFieldToMatch:** the API name of the field from which to use values from **sourceRecordCollection** as the list of valid values

## In short
This action will return either:
records of **objectName** with the fields in **returnFields**, where the record's value in **bindField** is one of the values in **validTextCollection**.
OR
records of **objectName** with the fields in **returnFields**, where the record's value in **bindField** is one of the values in the **sourceFieldToMatch** field in the **sourceRecordCollection** record collection.
In SOQL this translates to `SELECT returnFields FROM objectName WHERE bindField IN :validTextCollection`.

## Bulkification
This action is bulkified. That means that if a flow runs on a batch of records (a record-edit flow or via process builder), the apex action will run once per batch of 200 records, and execute one SOQL per batch.

## Limitations
When this action runs on batches of records (see **Bulkification**), it does not support batches where different records request different **objectName**s. This is due to how the action is bulkified.

You may encounter an error when a flow tries to access a field which is null on a record. This is due to a limitation with dynamic soql not including null fields in its results. To avoid this issue, do not leave `returnFields` blank. The action will then check for null in those fields so that it can be properly returned to the flow.

## Feedback
Any and all feedback is welcome!
