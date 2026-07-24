public with sharing class EmailInvalidatorJobStatusController {
  @TestVisible
  private static final Set<String> ACTIVE_STATUSES = new Set<String>{
    'Holding',
    'Processing'
  };

  @AuraEnabled
  public static JobStatus getActiveJobStatus() {
    JobStatus status = new JobStatus();
    status.invalidate = new ActionJobStatus();
    status.restore = new ActionJobStatus();
    status.scan = new ActionJobStatus();

    List<JobSnapshot> activeJobs = new List<JobSnapshot>();
    for (AsyncApexJob job : [
      SELECT ApexClass.Name, Status, JobItemsProcessed, TotalJobItems
      FROM AsyncApexJob
      WHERE
        ApexClass.Name IN (
          'InvalidateEmailBatch',
          'InvalidateEmailUndoBatch',
          'EmailFieldScannerBatch'
        )
        AND JobType = 'BatchApex'
        AND Status IN :ACTIVE_STATUSES
      ORDER BY CreatedDate DESC
    ]) {
      activeJobs.add(
        new JobSnapshot(
          job.ApexClass.Name,
          job.Status,
          job.JobItemsProcessed,
          job.TotalJobItems
        )
      );
    }

    applyJobStatuses(status, activeJobs);

    return status;
  }

  // Split out from getActiveJobStatus() so tests can drive it with
  // fabricated job data: AsyncApexJob's fields are all system-managed and
  // can't be set even on an in-memory instance, and real Holding/Processing
  // rows can't be produced deterministically in a test context (see
  // EmailInvalidatorJobStatusControllerTest for details).
  @TestVisible
  private static void applyJobStatuses(
    JobStatus status,
    List<JobSnapshot> jobs
  ) {
    for (JobSnapshot job : jobs) {
      ActionJobStatus actionStatus = getActionStatus(
        status,
        job.apexClassName
      );
      if (actionStatus == null) {
        continue;
      }

      actionStatus.active = true;
      actionStatus.jobCount++;

      // Surface progress for the first (most recent) job actually in
      // Processing; jobs still in Holding have no progress to report yet.
      if (job.status == 'Processing' && actionStatus.totalBatches == null) {
        actionStatus.batchesProcessed = job.jobItemsProcessed;
        actionStatus.totalBatches = job.totalJobItems;
      }
    }
  }

  // Minimal snapshot of the AsyncApexJob fields this class cares about.
  // Members are declared public (rather than private) so that marking the
  // class itself @TestVisible is enough to let tests construct and read it.
  @TestVisible
  private class JobSnapshot {
    public String apexClassName;
    public String status;
    public Integer jobItemsProcessed;
    public Integer totalJobItems;

    public JobSnapshot(
      String apexClassName,
      String status,
      Integer jobItemsProcessed,
      Integer totalJobItems
    ) {
      this.apexClassName = apexClassName;
      this.status = status;
      this.jobItemsProcessed = jobItemsProcessed;
      this.totalJobItems = totalJobItems;
    }
  }

  private static ActionJobStatus getActionStatus(
    JobStatus status,
    String apexClassName
  ) {
    if (apexClassName == 'InvalidateEmailBatch') {
      return status.invalidate;
    }
    if (apexClassName == 'InvalidateEmailUndoBatch') {
      return status.restore;
    }
    if (apexClassName == 'EmailFieldScannerBatch') {
      return status.scan;
    }
    return null;
  }

  // Response wrapper with per-action (Invalidate/Restore/Scan) job status.
  public class JobStatus {
    @AuraEnabled
    public ActionJobStatus invalidate;

    @AuraEnabled
    public ActionJobStatus restore;

    @AuraEnabled
    public ActionJobStatus scan;
  }

  // Whether a batch job for this action is currently Holding or Processing,
  // how many such jobs there are, and progress (batches processed / total
  // batches) for the most recent one that is actively Processing.
  public class ActionJobStatus {
    @AuraEnabled
    public Boolean active = false;

    @AuraEnabled
    public Integer jobCount = 0;

    @AuraEnabled
    public Integer batchesProcessed;

    @AuraEnabled
    public Integer totalBatches;
  }
}
