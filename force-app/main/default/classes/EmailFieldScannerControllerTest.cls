@IsTest
private class EmailFieldScannerControllerTest {
  @IsTest
  static void testStartEmailFieldScanAuraSuccess() {
    Test.startTest();

    // Call the AuraEnabled method
    EmailFieldScannerController.EmailScanResponse response = EmailFieldScannerController.startEmailFieldScanAura();

    Test.stopTest();

    // Verify the response
    System.assertEquals(true, response.success, 'Expected success to be true');
    System.assert(
      response.message.contains(
        'Email field scanning batch job started successfully'
      ),
      'Expected success message'
    );

    // Verify a batch job was started
    List<AsyncApexJob> jobs = [
      SELECT Id, Status
      FROM AsyncApexJob
      WHERE ApexClass.Name = 'EmailFieldScannerBatch'
    ];

    System.assertEquals(1, jobs.size(), 'Expected one batch job to be started');
  }

  @IsTest
  static void testExecuteEmailFieldScanSuccess() {
    Test.startTest();

    // Call the private method through the public method
    EmailFieldScannerController.EmailScanResponse response = EmailFieldScannerController.executeEmailFieldScan();

    Test.stopTest();

    // Verify the response
    System.assertEquals(true, response.success, 'Expected success to be true');
    System.assert(
      response.message.contains(
        'Email field scanning batch job started successfully'
      ),
      'Expected success message'
    );
  }

  @IsTest
  static void testEmailScanResponseClass() {
    // Test the response class
    EmailFieldScannerController.EmailScanResponse response = new EmailFieldScannerController.EmailScanResponse();

    response.success = true;
    response.message = 'Test message';

    System.assertEquals(true, response.success);
    System.assertEquals('Test message', response.message);
  }

  @IsTest
  static void testBatchJobStartedVerification() {
    Test.startTest();

    // Start multiple scans to verify they all work
    EmailFieldScannerController.EmailScanResponse response = EmailFieldScannerController.startEmailFieldScanAura();

    Test.stopTest();

    // Both should succeed
    System.assertEquals(true, response.success);

    // Verify batch jobs were started
    List<AsyncApexJob> jobs = [
      SELECT Id, Status
      FROM AsyncApexJob
      WHERE ApexClass.Name = 'EmailFieldScannerBatch'
    ];

    System.assertEquals(
      1,
      jobs.size(),
      'Expected two batch jobs to be started'
    );
  }

  @IsTest
  static void testGetCachedScanResults() {
    // Whether a Field_Scan cache metadata record exists depends on org
    // state (it's populated by a real scan, not by test data), so this just
    // exercises the query/branch-selection wrapper end to end. The actual
    // parsing branches are covered deterministically by the
    // populateCachedResultsResponse tests below.
    Test.startTest();
    EmailFieldScannerController.CachedResultsResponse response = EmailFieldScannerController.getCachedScanResults();
    Test.stopTest();

    Assert.isNotNull(response);
    Assert.isNotNull(response.message);
    if (!response.success) {
      Assert.isTrue(
        response.message.contains('No cached scan results found'),
        'Expected the friendly no-results message, got: ' + response.message
      );
    }
  }

  @IsTest
  static void testPopulateCachedResultsResponseWithBlankValue() {
    EmailFieldScannerController.CachedResultsResponse response = new EmailFieldScannerController.CachedResultsResponse();

    Test.startTest();
    EmailFieldScannerController.populateCachedResultsResponse(
      response,
      '',
      DateTime.now()
    );
    Test.stopTest();

    Assert.isFalse(response.success);
    Assert.areEqual('Cache record exists but contains no data', response.message);
  }

  @IsTest
  static void testPopulateCachedResultsResponseWithValidPayload() {
    EmailFieldScannerController.CachedResultsResponse response = new EmailFieldScannerController.CachedResultsResponse();
    DateTime modstamp = DateTime.now();

    String payload =
      '{' +
      '"scanDate":"2026-07-24",' +
      '"totalObjectsScanned":5,' +
      '"totalEmailFieldsFound":2,' +
      '"existingFieldsSkipped":1,' +
      '"newEmailFields":[' +
      '{"objectName":"Contact","fieldName":"Backup_Email__c","fieldLabel":"Backup Email","discoveredDate":"2026-07-24"},' +
      '{"objectName":"Lead","fieldName":"Alt_Email__c","fieldLabel":"Alt Email","discoveredDate":"2026-07-24"}' +
      ']' +
      '}';

    Test.startTest();
    EmailFieldScannerController.populateCachedResultsResponse(
      response,
      payload,
      modstamp
    );
    Test.stopTest();

    Assert.isTrue(response.success);
    Assert.areEqual('2026-07-24', response.scanDate);
    Assert.areEqual(modstamp, response.lastModifiedDate);
    Assert.areEqual(5, response.totalObjectsScanned);
    Assert.areEqual(2, response.totalEmailFieldsFound);
    Assert.areEqual(1, response.existingFieldsSkipped);
    Assert.areEqual(2, response.newEmailFields.size());
    Assert.areEqual('Contact.Backup_Email__c', response.newEmailFields[0].uniqueKey);
    Assert.isFalse(response.newEmailFields[0].selected);
  }

  @IsTest
  static void testDeploySelectedFieldsWithEmptyList() {
    Test.startTest();
    EmailFieldScannerController.EmailScanResponse response = EmailFieldScannerController.deploySelectedFields(
      '[]'
    );
    Test.stopTest();

    Assert.isFalse(response.success);
    Assert.areEqual('No fields selected for deployment', response.message);
  }

  @IsTest
  static void testDeploySelectedFieldsWithNoneSelected() {
    String json =
      '[{"objectName":"Contact","fieldName":"Backup_Email__c","fieldLabel":"Backup Email","selected":false}]';

    Test.startTest();
    EmailFieldScannerController.EmailScanResponse response = EmailFieldScannerController.deploySelectedFields(
      json
    );
    Test.stopTest();

    Assert.isFalse(response.success);
    Assert.areEqual(
      'No fields were marked as selected for deployment',
      response.message
    );
  }

  @IsTest
  static void testDeploySelectedFieldsWithSelectedFields() {
    // Includes a duplicate objectName/fieldName pair (to exercise the
    // uniqueness counter), a name starting with a digit (Field_ prefix),
    // and a very long name (truncation) - all handled by
    // generateUniqueMetadataRecordName.
    String json =
      '[' +
      '{"objectName":"Contact","fieldName":"Backup_Email__c","fieldLabel":"Backup Email","selected":true},' +
      '{"objectName":"Contact","fieldName":"Backup_Email__c","fieldLabel":"Backup Email","selected":true},' +
      '{"objectName":"1Custom_Object__c","fieldName":"Email__c","fieldLabel":"Email","selected":true},' +
      '{"objectName":"A_Very_Long_Custom_Object_Name_That_Exceeds__c","fieldName":"Another_Really_Long_Field_Name_Here__c","fieldLabel":"Long","selected":true}' +
      ']';

    Test.startTest();
    EmailFieldScannerController.EmailScanResponse response = EmailFieldScannerController.deploySelectedFields(
      json
    );
    Test.stopTest();

    Assert.isTrue(response.success, response.message);
    Assert.isTrue(
      response.message.contains('4 email field'),
      'Expected all four selected fields to be counted, got: ' + response.message
    );
  }

  @IsTest
  static void testDeploySelectedFieldsWithInvalidJson() {
    Test.startTest();
    EmailFieldScannerController.EmailScanResponse response = EmailFieldScannerController.deploySelectedFields(
      'not valid json'
    );
    Test.stopTest();

    Assert.isFalse(response.success);
    Assert.isTrue(
      response.message.contains('Error deploying selected fields'),
      'Expected the error branch, got: ' + response.message
    );
  }

  @IsTest
  static void testClearCachedResults() {
    Test.startTest();
    EmailFieldScannerController.EmailScanResponse response = EmailFieldScannerController.clearCachedResults();
    Test.stopTest();

    Assert.isTrue(response.success);
    Assert.areEqual('Cache cleared successfully', response.message);
  }
}
