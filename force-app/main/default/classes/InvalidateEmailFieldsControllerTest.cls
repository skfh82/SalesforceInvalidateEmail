/**
 * Test class for InvalidateEmailFieldsController
 * Tests the controller methods for retrieving Email_Invalidator_Fields__mdt records
 */
@isTest
private class InvalidateEmailFieldsControllerTest {
  @isTest
  static void testGetInvalidateEmailFields() {
    Test.startTest();

    List<InvalidateEmailFieldsController.InvalidateEmailField> result = InvalidateEmailFieldsController.getInvalidateEmailFields();

    Test.stopTest();

    // Assert that the method returns a list (even if empty)
    Assert.isNotNull(result, 'Result should not be null');

    // If there are any custom metadata records, verify they have the expected fields
    for (InvalidateEmailFieldsController.InvalidateEmailField field : result) {
      Assert.isNotNull(field.Id, 'Id should not be null');
      Assert.isNotNull(field.Label, 'Label should not be null');
      Assert.isNotNull(field.DeveloperName, 'DeveloperName should not be null');
      Assert.isNotNull(field.ObjectName, 'ObjectName should not be null');
      Assert.isNotNull(field.FieldName, 'FieldName should not be null');
    }
  }

  @IsTest
  static void testGetCustomMetadataObjectPrefix() {
    String expectedPrefix = Email_Invalidator_Fields__mdt.sobjecttype.getDescribe()
      .getKeyPrefix();

    System.assertEquals(
      expectedPrefix,
      InvalidateEmailFieldsController.getCustomMetadataObjectPrefix(),
      'Prefix does not match expected value'
    );
  }
}
