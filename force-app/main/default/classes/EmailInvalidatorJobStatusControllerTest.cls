@isTest
private class EmailInvalidatorJobStatusControllerTest {
  @isTest
  static void testNoActiveJobsReturnsAllFalse() {
    Test.startTest();
    EmailInvalidatorJobStatusController.JobStatus status = EmailInvalidatorJobStatusController.getActiveJobStatus();
    Test.stopTest();

    Assert.isFalse(
      status.invalidateActive,
      'No invalidate batch is running'
    );
    Assert.isFalse(status.restoreActive, 'No restore batch is running');
    Assert.isFalse(status.scanActive, 'No scan batch is running');
    Assert.areEqual(
      0,
      status.activeJobCount,
      'No jobs are Holding or Processing'
    );
    Assert.isNull(
      status.batchesProcessed,
      'No job is Processing, so there is no progress to report'
    );
    Assert.isNull(
      status.totalBatches,
      'No job is Processing, so there is no progress to report'
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
      status.invalidateActive,
      'A completed batch should not be reported as active'
    );
  }
}
