global with sharing class GetRecordsInTextCollection {
    @InvocableMethod
    global static List<FlowOutput> GetRecordsInTextCollection(List<FlowInput> inputs){
         
        Map<String,List<FlowInput>> fieldNameToInputs = new Map<String,List<FlowInput>>();
        Map<String, Set<String>> fieldNameToValidValues = new Map<String, Set<String>> ();
        Set<String> allReturnFields = new Set<String>();

        validateInputs(inputs); // throw an error if there's an issue, otherwise continue

        for (FlowInput input : inputs) {
            if (input.bindField == null) {
                input.bindField = 'id';
            }
            input.bindField = input.bindField.toLowerCase();
            // add the valid field values for this input to a map of field name to a set of valid values
            if (!fieldNameToValidValues.containsKey(input.bindField)) {
                fieldNameToValidValues.put(input.bindField, new Set<String>());
                // also add the bind field to the set of return fields in case it's not there yet
                allReturnFields.add(input.bindField);
            }
            fieldNameToValidValues.get(input.bindField)
                .addAll(input.validTextCollection);
            // add this input to a map of bind fields in this batch (which will usually be one) to inputs that use it
            if (!fieldNameToInputs.containsKey(input.bindField)) {
                fieldNameToInputs.put(input.bindField, new List<FlowInput>());
            }
            fieldNameToInputs.get(input.bindField).add(input);

            // add all the return fields to a set (in case different interviews request different fields)
            // note that we will return all fields for all the records.
            // Most of the time, all the interviews will request the same fields. Even if not, the user is not likely to notice, and we don't anticipate performance issues.
            if (input.returnFields != null) {
                for (String field : input.returnFields) {
                    allReturnFields.add(field.toLowerCase());
                }
            } else {
                Schema.SObjectType targetType = Schema.getGlobalDescribe()
                    .get(input.objectName);
                allReturnFields.addAll(
                    targetType.getDescribe().fields.getMap().keySet()
                );
            }
        }

        // build the soql
        String theSoql = buildSoql(
            inputs,
            allReturnFields,
            fieldNameToValidValues
        );

        // and fetch the records
        List<sObject> foundRecords = Database.query(theSoql);
        System.debug('>>>> found records: ' + foundRecords.size());

        // we will need a map of bind fields to each requested value to the list of records that match it, so that we can assign the matching records to the corresponding input(s)
        Map<String, Map<String, List<sObject>>> bindFieldToValueToRecordsMap = new Map<String, Map<String, List<sObject>>>();

        // prepare a row for each bind field in our map. We could really do this with an if within the next loop, but this way seems cleaner to me.
        for (String bindField : fieldNameToValidValues.keySet()) {
            bindFieldToValueToRecordsMap.put(
                bindField,
                new Map<String, List<sObject>>()
            );
        }

        // for each record that was found, put its value for each requested bind field into the map
        for (sObject record : foundRecords) {
            for (String bindField : fieldNameToValidValues.keySet()) {
                System.debug(
                    '>>>> bind field is ' +
                    bindField +
                    '. Will fetch value from record: ' +
                    record
                );
                String fieldVal = record.get(bindField)?.toString(); //do we want this to work on non-text fields?
                // add a key for this field value if necessary
                if (
                    !bindFieldToValueToRecordsMap.get(bindField)
                        .containsKey(fieldVal)
                ) {
                    bindFieldToValueToRecordsMap.get(bindField)
                        .put(fieldVal, new List<sObject>());
                }
                // add the record we found to the list of records for the field value (within this field)
                bindFieldToValueToRecordsMap.get(bindField)
                    .get(fieldVal)
                    .add(record);
            }
        }

        // now that we have a map to reference, loop through the original inputs
        // for each input's bind field, loop through the bind values, and add those matching records to a list to output

        List<FlowOutput> outputs = new List<FlowOutput>();

        for (FlowInput input : inputs) {
            Map<String, List<sObject>> fieldValToRecords = bindFieldToValueToRecordsMap.get(
                input.bindField
            );
            List<sObject> matchingRecords = new List<sObject>();
            for (String text : input.validTextCollection) {
                if (fieldValToRecords.containsKey(text)) {
                    matchingRecords.addAll(fieldValToRecords.get(text));
                }
            }
            FlowOutput output = new FlowOutput();
            output.matchingRecords = matchingRecords;
            outputs.add(output);
        }

        return outputs;
    }

    static String buildSoql(
        List<FlowInput> inputs,
        Set<String> allReturnFields,
        Map<String, Set<String>> fieldNameToValidValues
    ) {
        String theSoql =
            'SELECT ' + String.join(new List<String>(allReturnFields), ', ');
        theSoql += ' FROM ' + inputs[0].objectName; //we can take the object name from the first input in our list, since they will all be the same anyways
        // now the fun part - the WHERE! If there is only one bind field, it's simpler. If there are multiple, each needs to be in parens and split with OR
        theSoql += ' WHERE ';
        // loop through each bind field
        List<String> inClauses = new List<String>();
        for (String bindField : fieldNameToValidValues.keySet()) {
            String clause = bindField + ' IN (';
            List<String> textValues = new List<String>();
            for (String value : fieldNameToValidValues.get(bindField)) {
                textValues.add('\'' + value + '\'');
            }
            clause += String.join(textValues, ', ') + ')';

            // if there is more than one bind field, each clause needs to be wrapped in parens
            if (fieldNameToValidValues.size() > 1) {
                clause = '(' + clause + ')';
            }
            inClauses.add(clause);
        }

        theSoql += String.join(inClauses, ' OR ');
        System.debug('>>>> will fetch these records: ' + theSoql);
        return theSoql;
    }

    static void validateInputs(List<FlowInput> inputs) {
        Set<String> objNames = new Set<String>();
        for (FlowInput input : inputs) {
            objNames.add(input.objectName);
        }
        if (objNames.size() != 1) {
            throw new IllegalArgumentException(
                'All records must have the same object name'
            );
        }
        String objName = new List<String>(objNames)[0];
        if (
            (Type.forName(objName)?.newInstance() instanceof SObject) == false
        ) {
            throw new IllegalArgumentException(
                objName + ' is not a valid object'
            );
        }
    }

    global class FlowInput {
        @InvocableVariable(required=true)
        global String objectName;

        @InvocableVariable
        global List<String> returnFields;

        @InvocableVariable
        global String bindField;

        @InvocableVariable(required=true)
        global List<String> validTextCollection;
    }

    global class FlowOutput {
        @InvocableVariable
        global String errors;

        @InvocableVariable
        global List<SObject> matchingRecords;
    }
}
