public with sharing class EmailInvalidatorJobStatusController {
  @TestVisible
  private static final Set<String> ACTIVE_STATUSES = new Set<String>{
    'Holding',
    'Processing'
  };

  @AuraEnabled
  public static JobStatus getActiveJobStatus() {
    JobStatus status = new JobStatus();
    status.invalidateActive = false;
    status.restoreActive = false;
    status.scanActive = false;
    status.activeJobCount = 0;

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
      status.activeJobCount++;

      if (job.ApexClass.Name == 'InvalidateEmailBatch') {
        status.invalidateActive = true;
      } else if (job.ApexClass.Name == 'InvalidateEmailUndoBatch') {
        status.restoreActive = true;
      } else if (job.ApexClass.Name == 'EmailFieldScannerBatch') {
        status.scanActive = true;
      }

      // Surface progress for the first (most recent) job actually in
      // Processing; jobs still in Holding have no progress to report yet.
      if (job.Status == 'Processing' && status.totalBatches == null) {
        status.batchesProcessed = job.JobItemsProcessed;
        status.totalBatches = job.TotalJobItems;
      }
    }

    return status;
  }

  // Response wrapper indicating whether a batch job for each action is
  // currently Holding or Processing, how many such jobs there are in total,
  // and progress (batches processed / total batches) for the most recent
  // one that is actively Processing.
  public class JobStatus {
    @AuraEnabled
    public Boolean invalidateActive;

    @AuraEnabled
    public Boolean restoreActive;

    @AuraEnabled
    public Boolean scanActive;

    @AuraEnabled
    public Integer activeJobCount;

    @AuraEnabled
    public Integer batchesProcessed;

    @AuraEnabled
    public Integer totalBatches;
  }
}
