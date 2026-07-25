import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import invalidateAllConfiguredEmails from '@salesforce/apex/InvalidateEmailFlowAction.invalidateAllConfiguredEmailsAura';
import restoreAllConfiguredEmails from '@salesforce/apex/InvalidateEmailUndoFlowAction.restoreAllConfiguredEmailsAura';
import startEmailFieldScanAura from '@salesforce/apex/EmailFieldScannerController.startEmailFieldScanAura';
import isSandboxOrg from '@salesforce/apex/InvalidateEmailFlowAction.isSandboxOrg';
import getActiveJobStatus from '@salesforce/apex/EmailInvalidatorJobStatusController.getActiveJobStatus';

const JOB_STATUS_POLL_INTERVAL_MS = 10000;
const JOB_STATUS_SLOW_POLL_INTERVAL_MS = 60000;
const JOB_STATUS_SLOW_POLL_AFTER_MS = 2 * 60 * 1000;

export default class InvalidateEmail extends LightningElement {
  @wire(isSandboxOrg) isSandbox;

  isInvalidating = false;
  isRestoring = false;
  isScanning = false;

  invalidateJobActive = false;
  invalidateJobCount = 0;
  invalidateBatchesProcessed;
  invalidateTotalBatches;

  restoreJobActive = false;
  restoreJobCount = 0;
  restoreBatchesProcessed;
  restoreTotalBatches;

  scanJobActive = false;
  scanJobCount = 0;
  scanBatchesProcessed;
  scanTotalBatches;

  jobStatusPollHandle;
  pollingStartTime;

  connectedCallback() {
    this.pollingStartTime = Date.now();
    this.refreshJobStatus();
    this.scheduleNextPoll();
  }

  disconnectedCallback() {
    clearTimeout(this.jobStatusPollHandle);
  }

  scheduleNextPoll() {
    this.jobStatusPollHandle = setTimeout(() => {
      this.refreshJobStatus();
      this.scheduleNextPoll();
    }, this.getPollIntervalMs());
  }

  getPollIntervalMs() {
    const elapsed = Date.now() - this.pollingStartTime;
    return elapsed >= JOB_STATUS_SLOW_POLL_AFTER_MS
      ? JOB_STATUS_SLOW_POLL_INTERVAL_MS
      : JOB_STATUS_POLL_INTERVAL_MS;
  }

  async refreshJobStatus() {
    try {
      const status = await getActiveJobStatus();

      this.invalidateJobActive = status.invalidate.active;
      this.invalidateJobCount = status.invalidate.jobCount;
      this.invalidateBatchesProcessed = status.invalidate.batchesProcessed;
      this.invalidateTotalBatches = status.invalidate.totalBatches;

      this.restoreJobActive = status.restore.active;
      this.restoreJobCount = status.restore.jobCount;
      this.restoreBatchesProcessed = status.restore.batchesProcessed;
      this.restoreTotalBatches = status.restore.totalBatches;

      this.scanJobActive = status.scan.active;
      this.scanJobCount = status.scan.jobCount;
      this.scanBatchesProcessed = status.scan.batchesProcessed;
      this.scanTotalBatches = status.scan.totalBatches;
    } catch (err) {
      console.error('Error checking Email Invalidator job status: ', err);
    }
  }

  get isProductionOrg() {
    return this.isSandbox.data === false;
  }

  // Invalidate and Restore act on the same underlying data, so neither
  // button should be usable while anything would block the other.
  get isInvalidateOrRestoreDisabled() {
    return (
      this.isProductionOrg ||
      this.isInvalidating ||
      this.invalidateJobActive ||
      this.isRestoring ||
      this.restoreJobActive
    );
  }

  get isInvalidateDisabled() {
    return this.isInvalidateOrRestoreDisabled;
  }

  get isRestoreDisabled() {
    return this.isInvalidateOrRestoreDisabled;
  }

  get isScanDisabled() {
    return this.isScanning || this.scanJobActive;
  }

  get invalidateBannerMessage() {
    return this.buildBannerMessage(
      'Invalidate Emails',
      this.invalidateJobCount,
      this.invalidateBatchesProcessed,
      this.invalidateTotalBatches
    );
  }

  get restoreBannerMessage() {
    return this.buildBannerMessage(
      'Restore Emails',
      this.restoreJobCount,
      this.restoreBatchesProcessed,
      this.restoreTotalBatches
    );
  }

  get scanBannerMessage() {
    return this.buildBannerMessage(
      'Scan For Email Fields',
      this.scanJobCount,
      this.scanBatchesProcessed,
      this.scanTotalBatches
    );
  }

  buildBannerMessage(actionLabel, jobCount, batchesProcessed, totalBatches) {
    const count = jobCount || 0;
    const countMessage = `${count} job${count === 1 ? '' : 's'} pending.`;
    if (totalBatches != null) {
      return `${actionLabel}: Processing ${batchesProcessed} of ${totalBatches} batches. ${countMessage}`;
    }
    return `${actionLabel}: ${countMessage}`;
  }

  async handleInvalidateClick() {
    // Call the AuraEnabled method to start the batch process
    this.isInvalidating = true;
    try {
      let response = await invalidateAllConfiguredEmails();

      console.log("Response from function: ");
      console.log(response);
      if (response.success) {
        // Show success toast (red, matching the destructive Invalidate button)
        this.dispatchEvent(
          new ShowToastEvent({
            title: 'Email Invalidation Started',
            message: response.message,
            variant: 'error'
          })
        );
      } else {
        // Show error toast
        this.dispatchEvent(
          new ShowToastEvent({
            title: 'Error Starting Email Invalidation',
            message: response.message,
            variant: 'error'
          })
        );
      }
    } catch (err) {
      // Show error toast
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Exception Occurred while Starting Email Invalidation',
          message: 'Resolution by developer is probably required.',
          variant: 'error'
        })
      );
    } finally {
      this.isInvalidating = false;
      this.refreshJobStatus();
    }
  }

  async handleRestoreClick() {
    // Call the AuraEnabled method to start the restore process
    this.isRestoring = true;
    try {
      let response = await restoreAllConfiguredEmails();

      console.log("Response from restore function: ");
      console.log(response);
      if (response.success) {
        // Show success toast (green, matching the success Restore button)
        this.dispatchEvent(
          new ShowToastEvent({
            title: 'Email Restoration Started',
            message: response.message,
            variant: 'success'
          })
        );
      } else {
        // Show error toast
        this.dispatchEvent(
          new ShowToastEvent({
            title: 'Error Starting Email Restoration',
            message: response.message,
            variant: 'error'
          })
        );
      }
    } catch (err) {
      // Show error toast
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Exception Occurred while Starting Email Restoration',
          message: 'Resolution by developer is probably required.',
          variant: 'error'
        })
      );
    } finally {
      this.isRestoring = false;
      this.refreshJobStatus();
    }
  }

  async handleEmailScanClick() {
    // Call the AuraEnabled method to start the email field scanning batch process
    this.isScanning = true;
    try {
      let response = await startEmailFieldScanAura();

      console.log("Response from email scan function: ");
      console.log(response);
      if (response.success) {
        // Show success toast (blue, matching the brand Scan button)
        this.dispatchEvent(
          new ShowToastEvent({
            title: 'Email Field Scan Started',
            message: response.message,
            variant: 'info'
          })
        );
      } else {
        // Show error toast
        this.dispatchEvent(
          new ShowToastEvent({
            title: 'Error Starting Email Field Scan',
            message: response.message,
            variant: 'error'
          })
        );
      }
    } catch (err) {
      // Show error toast
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Exception Occurred while Starting Email Field Scan',
          message: 'Resolution by developer is probably required.',
          variant: 'error'
        })
      );
    } finally {
      this.isScanning = false;
      this.refreshJobStatus();
    }
  }
}
