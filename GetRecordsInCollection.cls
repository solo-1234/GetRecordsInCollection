global with sharing class GetRecordsInCollection {

    @InvocableMethod
    global static List<FlowOutput> GetRecordsInCollection(List<FlowInput> inputs){
        
        //this code does not account for the possiblity of one batch containing different objects. It needs to unless we can change the input variable to sObject,
        //since that needs to be specified when adding the action to a flow
        //either way, we do need to account for the (rare) possibility that one batch could contain different bind fields
         
        Map<String,List<FlowInput>> FieldNameToInputs = new Map<String,List<FlowInput>>();
        Map<String, Set<String>> fieldNameToValidValues = new Map<String, Set<String>> ();
        Set<String> allReturnFields = new Set<String>();
        
        for(FlowInput input : inputs){
            // add the valid field values for this input to a map of field name to a set of valid values
            if (!fieldNameToValidValues.containsKey(input.bindField)){
                fieldNameToValidValues.put(input.bindField, new Set<String>());
                //also add the bind field to the set of return fields in case it's not there yet
                allReturnFields.add(input.bindField);
            }
            fieldNameToValidValues.get(input.bindField).addAll(input.validTextCollection);
            // add this input to a map of bind fields in this batch (which will usually be one) to inputs that use it
            if (!FieldNameToInputs.containsKey(input.bindField)){
                FieldNameToInputs.put(input.bindField, new List<FlowInput>());
            }
            FieldNameToInputs.get(input.bindField).add(input);
            
            //add all the return fields to a set (in case different interviews request different fields)
            allReturnFields.addAll(input.returnFields);
        }
       
        //now build the soql
        String theSoql = 'SELECT ' +  String.join(new List<String>(allReturnFields), ', ');
        theSoql += ' FROM ' + inputs[0].objectName; //we can take the object name from the first input in our list, since they will all be the same anyways
		//now the fun part - the WHERE! If there is only one bind field, it's simpler. If there are multiple, each needs to be in parens and split with OR
        theSoql += ' WHERE ';
        //loop through each bind field
        List <String> inClauses = new List <String> ();
        for (String bindField : fieldNameToValidValues.keySet()){
            String clause = bindField + ' IN (';
            List <String> textValues = new List<String> ();
            for (String value :fieldNameToValidValues.get(bindField) ){
                textValues.add('\''+ value + '\'');
            }
            clause += String.join(textValues, ', ') + ')';
            
            //if there is more than one bind field, each clause needs to be wrapped in parens
            if(fieldNameToValidValues.size() > 1){
                clause = '(' + clause + ')';
            }
            inClauses.add(clause);
        }
        
        theSoql += String.join(inClauses,', ');
        System.debug('>>>> will fetch these records: ' + theSoql);
        
        //and fetch the records
        List <sObject> foundRecords = Database.query(theSoql);
        
        //after fetching the records, loop through them.
        //for each of our bind fields (objNameToInputs.keySet), prep a map of the valid text to all the records that match it
        //so this will be a map of bind fields to a map of valid value to all the records that match it
        //we'll loop through records, then bind fields, check if it has a row for the value it has in that field, and add it
        Map <String, Map <String, List <sObject>>> bindFieldToValueToRecordsMap = new Map <String, Map <String, List <sObject>>> ();
        
        //prepare a row for each bind field in bindFieldToValueToRecordsMap. We could really do this with an if within the next loop, but this way seems cleaner to me.
        for (String bindField : fieldNameToValidValues.keySet()){
            bindFieldToValueToRecordsMap.put(bindField, new Map <String, List <sObject>>());
        }
        
        for (sObject record : foundRecords){
            for (String bindField : fieldNameToValidValues.keySet()){
                String fieldVal = record.get(bindField).toString(); //do we want this to work on non-text fields?
                //add a key for this field value if necessary
                if (!bindFieldToValueToRecordsMap.get(bindField).containsKey(fieldVal)){
                    bindFieldToValueToRecordsMap.get(bindField).put(fieldVal, new List <sObject> ());
                }
                //add the record we found to the list of records for the field value (within this field)
                bindFieldToValueToRecordsMap.get(bindField).get(fieldVal).add(record);
            }
        }
        
        //now we can loop through the original inputs
        //for each input's find field
        //find in bindFieldToValueToRecordsMap
        //loop through the bind values from our input
        //for each one, fetch any relevant rows from the Map <String, sObject>
        //and add them to a temp list
        //then add a new output with that temp list to our output list
        //and do the next input
        
        List <FlowOutput> outputs = new List <FlowOutput> ();
        
        for(FlowInput input : inputs){
            Map <String, List<sObject>> fieldValToRecords = bindFieldToValueToRecordsMap.get(input.bindField);
            List <sObject> matchingRecords = new List <sObject>();
            for (String text : input.validTextCollection){
                if (fieldValToRecords.containsKey(text)){
                    matchingRecords.addAll(fieldValToRecords.get(text));
                }
            }
            System.debug('>>>> found ' + matchingRecords.size() + ' matching records for input');
            FlowOutput output = new FlowOutput ();
            output.matchingRecords = matchingRecords;
            outputs.add(output);
        }
        
        //right now it returns all return fields to all inputs, even if different inputs requested different fields. this might be just fine.
        return outputs;
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
       
	//it would be useful to be able to specify more filters, either in soql format or in field => value format      
    }
   
    global class FlowOutput {
        @InvocableVariable
        global String errors;
       
        @InvocableVariable
        global List<SObject> matchingRecords;
    }

}
