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

  // AsyncApexJob's fields are all system-managed (not settable, even on an
  // in-memory instance), so the loop logic is driven through the
  // JobSnapshot DTO instead. This exercises the active/progress-tracking
  // branches that testJobsAreNotActiveAfterCompletion can't reach.
  @isTest
  static void testApplyJobStatusesMarksActiveAndTracksProgress() {
    EmailInvalidatorJobStatusController.JobStatus status = new EmailInvalidatorJobStatusController.JobStatus();
    status.invalidate = new EmailInvalidatorJobStatusController.ActionJobStatus();
    status.restore = new EmailInvalidatorJobStatusController.ActionJobStatus();
    status.scan = new EmailInvalidatorJobStatusController.ActionJobStatus();

    List<EmailInvalidatorJobStatusController.JobSnapshot> jobs = new List<EmailInvalidatorJobStatusController.JobSnapshot>{
      new EmailInvalidatorJobStatusController.JobSnapshot(
        'InvalidateEmailBatch',
        'Holding',
        0,
        0
      ),
      new EmailInvalidatorJobStatusController.JobSnapshot(
        'InvalidateEmailBatch',
        'Processing',
        3,
        10
      ),
      new EmailInvalidatorJobStatusController.JobSnapshot(
        'InvalidateEmailUndoBatch',
        'Processing',
        1,
        4
      ),
      new EmailInvalidatorJobStatusController.JobSnapshot(
        'EmailFieldScannerBatch',
        'Holding',
        0,
        0
      ),
      new EmailInvalidatorJobStatusController.JobSnapshot(
        'SomeUnrelatedBatch',
        'Processing',
        1,
        1
      )
    };

    Test.startTest();
    EmailInvalidatorJobStatusController.applyJobStatuses(status, jobs);
    Test.stopTest();

    Assert.isTrue(status.invalidate.active, 'Invalidate should be active');
    Assert.areEqual(
      2,
      status.invalidate.jobCount,
      'Both Holding and Processing invalidate jobs should count'
    );
    Assert.areEqual(
      3,
      status.invalidate.batchesProcessed,
      'Progress should come from the Processing job'
    );
    Assert.areEqual(
      10,
      status.invalidate.totalBatches,
      'Progress should come from the Processing job'
    );

    Assert.isTrue(status.restore.active, 'Restore should be active');
    Assert.areEqual(1, status.restore.jobCount);
    Assert.areEqual(1, status.restore.batchesProcessed);
    Assert.areEqual(4, status.restore.totalBatches);

    Assert.isTrue(status.scan.active, 'Scan should be active');
    Assert.areEqual(1, status.scan.jobCount);
    Assert.isNull(
      status.scan.batchesProcessed,
      'A Holding job has no progress to report yet'
    );
    Assert.isNull(status.scan.totalBatches);
  }
}
