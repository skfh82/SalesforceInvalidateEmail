@isTest
private class EmailInvalidatorJobStatusControllerTest {
  @isTest
  static void testNoActiveJobsReturnsAllFalse() {
    Test.startTest();
    EmailInvalidatorJobStatusController.JobStatus status = EmailInvalidatorJobStatusController.getActiveJobStatus();
    Test.stopTest();

    assertInactive(status.invalidate, 'invalidate');
    assertInactive(status.restore, 'restore');
    assertInactive(status.scan, 'scan');
  }

  private static void assertInactive(
    EmailInvalidatorJobStatusController.ActionJobStatus actionStatus,
    String label
  ) {
    Assert.isFalse(actionStatus.active, 'No ' + label + ' batch is running');
    Assert.areEqual(
      0,
      actionStatus.jobCount,
      'No ' + label + ' jobs are Holding or Processing'
    );
    Assert.isNull(
      actionStatus.batchesProcessed,
      'No ' + label + ' job is Processing, so there is no progress to report'
    );
    Assert.isNull(
      actionStatus.totalBatches,
      'No ' + label + ' job is Processing, so there is no progress to report'
    );
  }

  // Note: AsyncApexJob rows can't be inserted or otherwise fabricated in a
  // test, and Apex tests run enqueued batch jobs synchronously to
  // completion at Test.stopTest() rather than passing through the real
  // Holding/Processing states, so those states can't be reproduced
  // deterministically here. The Status IN ('Holding', 'Processing') query
  // filter was verified directly against a live org instead: a freshly
  // enqueued InvalidateEmailBatch job reports Holding immediately and
  // Processing shortly after, both correctly picked up by this query.

  @isTest
  static void testJobsAreNotActiveAfterCompletion() {
    Contact testContact = new Contact(
      FirstName = 'Test',
      LastName = 'JobStatus',
      Email = 'jobstatus@example.com'
    );
    insert testContact;

    Test.startTest();
    Database.executeBatch(
      new InvalidateEmailBatch('Contact', new Set<String>{ 'Email' })
    );
    Test.stopTest();

    // After stopTest() the batch has finished (Completed), so it should no
    // longer be reported as active.
    EmailInvalidatorJobStatusController.JobStatus status = EmailInvalidatorJobStatusController.getActiveJobStatus();

    Assert.isFalse(
      status.invalidate.active,
      'A completed batch should not be reported as active'
    );
  }
}
