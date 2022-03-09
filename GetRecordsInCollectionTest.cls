@isTest
private class GetRecordsInCollectionTest {
    
    @testSetup
    static void testSetup(){
        List <Account> accounts = new List <Account> ();
        for (integer i = 1; i <= 8; i++){
            Account account = new Account (Name = 'account ' + i,
                                 AccountNumber = '123');
            accounts.add(account);
        }
        accounts[0].site = 'US';
        accounts[1].site = 'US';
        accounts[2].site = 'US';
        accounts[3].site = 'CA';
        accounts[4].site = 'CA';
        accounts[5].site = 'UK';
        accounts[6].site = 'UK';
        
        insert accounts;
    }
    
    @IsTest
    static void getRecords_AccountsInUS_Three() {
        List<String> validTextCollection = new List <String> {'US'};
        List <GetRecordsInCollection.FlowInput> inputList = prepSingleInputList('Account','Site',validTextCollection);
        List <Account> accountList = GetRecordsInCollection.GetRecordsInCollection(inputList)[0].matchingRecords;
        System.assertEquals(3, accountList.size(),'Should find 3 accounts with site: US');
    }
    
    @IsTest
    static void getRecords_AccountsWithHotOrWarmRating_Three() {
        List<String> validTextCollection = new List <String> {'US','CA'};
        List <GetRecordsInCollection.FlowInput> inputList = prepSingleInputList('Account','Site',validTextCollection);
        List <Account> accountList = GetRecordsInCollection.GetRecordsInCollection(inputList)[0].matchingRecords;
        System.assertEquals(5, accountList.size(),'Should find 5 accounts with rating: hot or warm');
    }
    
    @IsTest
    static void getRecords_AccountsByIdNoFields_Three() {
        List <Account> accs = [SELECT Id FROM Account LIMIT 3];
        List <String> validIds = new List <String> {accs[0].Id, accs[1].Id, accs[2].Id};
        List <GetRecordsInCollection.FlowInput> inputList = prepSingleInputList('Account',null,validIds);
        inputList[0].returnFields = null;
        List <Account> accountList = GetRecordsInCollection.GetRecordsInCollection(inputList)[0].matchingRecords;
        System.assertEquals(3, accountList.size(),'Should find 3 accounts matched on id');
    }
    
    @IsTest
    static void getRecords_InvalidObject_ThrowError() {
        List<String> validTextCollection = new List <String> {'US','CA'};
        List <GetRecordsInCollection.FlowInput> inputList = prepSingleInputList('Nothing','No_Field__c',validTextCollection);
        Boolean hasError = false;
        try{
            List <Account> accountList = GetRecordsInCollection.GetRecordsInCollection(inputList)[0].matchingRecords;
        } catch (IllegalArgumentException e){
            hasError = true;
        }
        System.assert(hasError,'Should throw an exception if the object is invalid');
    }
    
    // 
    @IsTest
    static void getRecords_MatchIds_3(){
        List <Account> accounts = new List <Account>();
        accounts.add(new Account (Name = 'Acct 1'));
        accounts.add(new Account (Name = 'Acct 2'));
        accounts.add(new Account (Name = 'Acct 3'));
        accounts.add(new Account (Name = 'Acct 4'));
        insert accounts;
        
        List <Contact> contacts = new List <Contact> ();
        contacts.add(new Contact (AccountId = accounts[0].Id, FirstName = 'First', LastName = 'Last'));
        contacts.add(new Contact (AccountId = accounts[1].Id, FirstName = 'First', LastName = 'Last'));
        contacts.add(new Contact (AccountId = accounts[2].Id, FirstName = 'First', LastName = 'Last'));
        contacts.add(new Contact (AccountId = accounts[2].Id, FirstName = 'First', LastName = 'Last'));
       	insert contacts; 
        
        
        GetRecordsInCollection.FlowInput input = new GetRecordsInCollection.FlowInput();
        input.objectName = 'Account';
        input.returnFields = new List <String> {'Id', 'Name'};
        input.bindField = 'Id';
        input.sourceRecordCollection = contacts;
        input.sourceFieldToMatch = 'AccountId';
        List <GetRecordsInCollection.FlowInput> inputs = new List <GetRecordsInCollection.FlowInput>{input};
        List <GetRecordsInCollection.FlowOutput> outputs = GetRecordsInCollection.GetRecordsInCollection(inputs);
        System.assertEquals(3, outputs[0].matchingRecords.size(), 'Should find 3 accounts that match these 4 contacts');
    }
    

    
    // private method to simplify creating FlowInput records for tests
    private static List <GetRecordsInCollection.FlowInput> prepSingleInputList (String objectName,  String bindField, List<String> validTextCollection){
        GetRecordsInCollection.FlowInput input = new GetRecordsInCollection.FlowInput();
        input.objectName = objectName;
        input.returnFields = new List<String> {'Id','AccountNumber'};
        input.bindField = bindField;
        input.validTextCollection = validTextCollection;        
        List<GetRecordsInCollection.FlowInput> inputs = new List <GetRecordsInCollection.FlowInput> {input};
        return inputs;
    }
   
    
    // here starts bulkified testing
    
    @IsTest
    static void getRecords_MultipleDifferentObjects_ThrowError() {
        GetRecordsInCollection.FlowInput input = new GetRecordsInCollection.FlowInput();
        input.objectName = 'Account';
        input.returnFields = new List<String> {'Id','Site'};
        input.bindField = 'AccountNumber';
        input.validTextCollection = new List<String> {'US','CA'};        

        GetRecordsInCollection.FlowInput input2 = input.clone();
        input2.objectName = 'Contact';
        
        List <GetRecordsInCollection.FlowInput> inputList = new List <GetRecordsInCollection.FlowInput> {input, input2};
        Boolean hasError = false;
        try{
            List <Account> accountList = GetRecordsInCollection.GetRecordsInCollection(inputList)[0].matchingRecords;
        } catch (IllegalArgumentException e){
            hasError = true;
        }
        System.assert(hasError,'Should throw an exception if batched requests reference different objects');
    }
    
    @IsTest
    static void getRecords_MultipleRequests_OneSOQL() {
        GetRecordsInCollection.FlowInput input = new GetRecordsInCollection.FlowInput();
        input.objectName = 'Account';
        input.returnFields = new List<String> {'Id','AccountNumber'};
        input.bindField = 'Site';
        input.validTextCollection = new List<String> {'US','CA'};        
        GetRecordsInCollection.FlowInput input2 = input.clone();
        List <GetRecordsInCollection.FlowInput> inputList = new List <GetRecordsInCollection.FlowInput> {input, input2};
        Test.startTest();
        List <GetRecordsInCollection.FlowOutput> flowOutputs = GetRecordsInCollection.GetRecordsInCollection(inputList);
        Integer numQueries = Limits.getQueries();
        Test.stopTest();
        System.assertEquals(1, numQueries,'Should execute one query even with multiple requests');
    }
        
    @IsTest
    static void getRecords_MultipleBindFields_OneSOQLAndCorrectValues() {
        GetRecordsInCollection.FlowInput input = new GetRecordsInCollection.FlowInput();
        input.objectName = 'Account';
        input.returnFields = new List<String> {'Id','AccountNumber'};
        input.bindField = 'Site';
        input.validTextCollection = new List<String> {'US','CA'};        

        GetRecordsInCollection.FlowInput input2 = input.clone();
        input2.bindField = 'AccountNumber';
        input2.validTextCollection = new List <String> {'123','nothing'};
        
        List <GetRecordsInCollection.FlowInput> inputList = new List <GetRecordsInCollection.FlowInput> {input, input2};
        Test.startTest();
        List <GetRecordsInCollection.FlowOutput> flowOutputs = GetRecordsInCollection.GetRecordsInCollection(inputList);
        Integer numQueries = Limits.getQueries();
        System.assertEquals(1, numQueries,'Should execute one query even with multiple requests');
        GetRecordsInCollection.FlowOutput firstResult = flowOutputs[0];
        GetRecordsInCollection.FlowOutput secondResult = flowOutputs[1];
        System.assertEquals(5, firstResult.matchingRecords.size(), 'Should find 5 accounts with site US or CA');
        System.assertEquals(8, secondResult.matchingRecords.size(), 'Should find 8 accounts with Account Number: 123');
        Test.stopTest();
    }

    @IsTest
    static void getRecords_WithAndWithoutTextCol_ThrowError(){
        List <Account> accounts = new List <Account>();
        accounts.add(new Account (Name = 'Acct 1'));
        insert accounts;
        
        List <Contact> contacts = new List <Contact> ();
        contacts.add(new Contact (AccountId = accounts[0].Id, FirstName = 'First', LastName = 'Last'));
        contacts.add(new Contact (AccountId = accounts[0].Id, FirstName = 'First', LastName = 'Last'));
        insert contacts; 
        
        List <GetRecordsInCollection.FlowInput> inputs = prepSingleInputList('Account','Site',new List<String> {'US','CA'});

        GetRecordsInCollection.FlowInput input = new GetRecordsInCollection.FlowInput();
        input.objectName = 'Account';
        input.returnFields = new List <String> {'Id', 'Name'};
        input.bindField = 'Id';
        input.sourceRecordCollection = contacts;
        input.sourceFieldToMatch = 'AccountId';
        inputs.add(input);
        
        Boolean hasError = false;
        try{
            List <Account> accountList = GetRecordsInCollection.GetRecordsInCollection(inputs)[0].matchingRecords;
        } catch (IllegalArgumentException e){
            hasError = true;
        }
        System.assert(hasError,'Should throw an exception if batched requests contain some inputs with a ValidTextCollection and some without');
        
    }
    
}
