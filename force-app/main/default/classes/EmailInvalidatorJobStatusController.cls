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
      ActionJobStatus actionStatus = getActionStatus(
        status,
        job.ApexClass.Name
      );
      if (actionStatus == null) {
        continue;
      }

      actionStatus.active = true;
      actionStatus.jobCount++;

      // Surface progress for the first (most recent) job actually in
      // Processing; jobs still in Holding have no progress to report yet.
      if (job.Status == 'Processing' && actionStatus.totalBatches == null) {
        actionStatus.batchesProcessed = job.JobItemsProcessed;
        actionStatus.totalBatches = job.TotalJobItems;
      }
    }

    return status;
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
