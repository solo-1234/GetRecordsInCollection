@isTest
private class GetRecordsInCollectionTest {
   
    @testSetup
    static void testSetup(){
        List <Lead> leads = new List <Lead> ();
        for (integer i = 1; i <= 8; i++){
            Lead lead = new Lead (FirstName = 'first ' + i,
                                 LastName = 'last ' + i,
                                 Company = 'company');
            leads.add(lead);
        }
        leads[0].rating = 'Hot';
        leads[1].rating = 'Hot';
        leads[2].rating = 'Hot';
        leads[3].rating = 'Warm';
        leads[4].rating = 'Warm';
        leads[5].rating = 'Cool';
        leads[6].rating = 'Cool';
        
        insert leads;
    }
    
    @IsTest
    static void testSetup_HasEightLeads() {
        List <Lead> leadList = [SELECT Id FROM Lead WHERE Company = 'company'];
        System.assertEquals(8, leadList.size(),'Should insert 8 leads');
    }
    
    @IsTest
    static void getRecords_LeadsWithHotRating_Three() {
        List<String> validTextCollection = new List <String> {'Hot'};
        List <GetRecordsInCollection.FlowInput> inputList = prepSingleInputList('Lead','Rating',validTextCollection);
        List <Lead> leadList = GetRecordsInCollection.GetRecordsInCollection(inputList)[0].matchingRecords;
        System.assertEquals(3, leadList.size(),'Should find 3 leads with rating: hot');
    }
    
    @IsTest
    static void getRecords_LeadsWithHotOrWarmRating_Three() {
        List<String> validTextCollection = new List <String> {'Hot','Warm'};
        List <GetRecordsInCollection.FlowInput> inputList = prepSingleInputList('Lead','Rating',validTextCollection);
        List <Lead> leadList = GetRecordsInCollection.GetRecordsInCollection(inputList)[0].matchingRecords;
        System.assertEquals(5, leadList.size(),'Should find 5 leads with rating: hot or warm');
    }
    
    @IsTest
    static void getRecords_InvalidObject_ThrowError() {
        List<String> validTextCollection = new List <String> {'Hot','Warm'};
        List <GetRecordsInCollection.FlowInput> inputList = prepSingleInputList('Nothing','No_Field__c',validTextCollection);
        Boolean hasError = false;
        try {
            List <Lead> leadList = GetRecordsInCollection.GetRecordsInCollection(inputList)[0].matchingRecords;
        } catch (IllegalArgumentException e) {
            hasError = true;
        }
        System.assert(hasError,'Should throw an exception if the object is invalid');

    }
    
    // private method to simplify creating FlowInput records for tests
    private static List <GetRecordsInCollection.FlowInput> prepSingleInputList (String objectName,  String bindField, List<String> validTextCollection){
        GetRecordsInCollection.FlowInput input = new GetRecordsInCollection.FlowInput();
        input.objectName = objectName;
        input.returnFields = new List<String> {'Id','Rating'};
        input.bindField = bindField;
        input.validTextCollection = validTextCollection;        
        List<GetRecordsInCollection.FlowInput> inputs = new List <GetRecordsInCollection.FlowInput> {input};
        return inputs;
    }
    
    // here starts bulkified testing
    
    @IsTest
    static void getRecords_MultipleDifferentObjects_ThrowError() {
        GetRecordsInCollection.FlowInput input = new GetRecordsInCollection.FlowInput();
        input.objectName = 'Lead';
        input.returnFields = new List<String> {'Id','Rating'};
        input.bindField = 'rating';
        input.validTextCollection = new List<String> {'Hot','Warm'};        
        GetRecordsInCollection.FlowInput input2 = input.clone();
        input2.objectName = 'Contact';
        List <GetRecordsInCollection.FlowInput> inputList = new List <GetRecordsInCollection.FlowInput> {input, input2};
        Boolean hasError = false;
        try{
            List <Lead> leadList = GetRecordsInCollection.GetRecordsInCollection(inputList)[0].matchingRecords;
        } catch (IllegalArgumentException e) {
            hasError = true;
        }
        System.assert(hasError, 'Should throw an exception if batched requests reference different objects');
    }
    
    @IsTest
    static void getRecords_MultipleRequests_OneSOQL() {
        GetRecordsInCollection.FlowInput input = new GetRecordsInCollection.FlowInput();
        input.objectName = 'Lead';
        input.returnFields = new List<String> {'Id','Rating'};
        input.bindField = 'Rating';
        input.validTextCollection = new List<String> {'Hot','Warm'};        
        GetRecordsInCollection.FlowInput input2 = input.clone();
        List <GetRecordsInCollection.FlowInput> inputList = new List <GetRecordsInCollection.FlowInput> {input, input2};
        Test.startTest();
        List <GetRecordsInCollection.FlowOutput> flowOutputs = GetRecordsInCollection.GetRecordsInCollection(inputList);
        Integer numQueries = Limits.getQueries();
        Test.stopTest();
        System.assertEquals(1, numQueries, 'Should execute one query even with multiple requests');
    }
    
    
    @IsTest
    static void getRecords_MultipleBindFields_OneSOQLAndCorrectValues() {
        GetRecordsInCollection.FlowInput input = new GetRecordsInCollection.FlowInput();
        input.objectName = 'Lead';
        input.returnFields = new List<String> {'Id','Rating'};
        input.bindField = 'Rating';
        input.validTextCollection = new List<String> {'Hot','Warm'};        
        GetRecordsInCollection.FlowInput input2 = input.clone();
        input2.bindField = 'Company';
        input2.validTextCollection = new List <String> {'company','nothing'};
        List <GetRecordsInCollection.FlowInput> inputList = new List <GetRecordsInCollection.FlowInput> {input, input2};
        Test.startTest();
        List <GetRecordsInCollection.FlowOutput> flowOutputs = GetRecordsInCollection.GetRecordsInCollection(inputList);
        Integer numQueries = Limits.getQueries();
        System.assertEquals(1, numQueries,'Should execute one query even with multiple requests');
    	GetRecordsInCollection.FlowOutput firstResult = flowOutputs[0];
        GetRecordsInCollection.FlowOutput secondResult = flowOutputs[1];
        System.assertEquals(5, firstResult.matchingRecords.size(), 'Should find 5 leads with rating hot or warm');
        System.assertEquals(8, secondResult.matchingRecords.size(), 'Should find 8 leads with company: company');
        Test.stopTest();
    }
    
}
