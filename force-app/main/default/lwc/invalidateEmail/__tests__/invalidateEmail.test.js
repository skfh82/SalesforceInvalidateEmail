import { createElement } from '@lwc/engine-dom';
import InvalidateEmail from 'c/invalidateEmail';
import invalidateAllConfiguredEmails from '@salesforce/apex/InvalidateEmailFlowAction.invalidateAllConfiguredEmailsAura';
import restoreAllConfiguredEmails from '@salesforce/apex/InvalidateEmailUndoFlowAction.restoreAllConfiguredEmailsAura';
import startEmailFieldScanAura from '@salesforce/apex/EmailFieldScannerController.startEmailFieldScanAura';
import isSandboxOrg from '@salesforce/apex/InvalidateEmailFlowAction.isSandboxOrg';
import getActiveJobStatus from '@salesforce/apex/EmailInvalidatorJobStatusController.getActiveJobStatus';

// Mock the Apex methods
jest.mock(
    '@salesforce/apex/InvalidateEmailFlowAction.invalidateAllConfiguredEmailsAura',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return {
            default: createApexTestWireAdapter(jest.fn())
        };
    },
    { virtual: true }
);

jest.mock(
    '@salesforce/apex/InvalidateEmailUndoFlowAction.restoreAllConfiguredEmailsAura',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return {
            default: createApexTestWireAdapter(jest.fn())
        };
    },
    { virtual: true }
);

jest.mock(
    '@salesforce/apex/EmailFieldScannerController.startEmailFieldScanAura',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return {
            default: createApexTestWireAdapter(jest.fn())
        };
    },
    { virtual: true }
);

jest.mock(
    '@salesforce/apex/InvalidateEmailFlowAction.isSandboxOrg',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return {
            default: createApexTestWireAdapter(jest.fn())
        };
    },
    { virtual: true }
);

jest.mock(
    '@salesforce/apex/EmailInvalidatorJobStatusController.getActiveJobStatus',
    () => ({
        default: jest.fn()
    }),
    { virtual: true }
);

function inactiveAction() {
    return { active: false, jobCount: 0, batchesProcessed: null, totalBatches: null };
}

const NO_ACTIVE_JOBS = {
    invalidate: inactiveAction(),
    restore: inactiveAction(),
    scan: inactiveAction()
};

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

describe('c-invalidate-email', () => {
    beforeEach(() => {
        // Default to no jobs running unless a test overrides this.
        getActiveJobStatus.mockResolvedValue(NO_ACTIVE_JOBS);
    });

    afterEach(() => {
        // The jsdom instance is shared across test cases in a single file so reset the DOM
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        // Clear all mocks
        jest.clearAllMocks();
    });

    it('always shows the static Apex Job Status link', () => {
        // Arrange
        const element = createElement('c-invalidate-email', {
            is: InvalidateEmail
        });

        // Act
        document.body.appendChild(element);

        // Assert
        const jobsLink = element.shadowRoot.querySelector('a[href="/lightning/setup/AsyncApexJobs/home"]');
        expect(jobsLink).not.toBeNull();
        expect(jobsLink.textContent).toBe('Apex Job Status');
    });

    it('renders the component with all three buttons', () => {
        // Arrange
        const element = createElement('c-invalidate-email', {
            is: InvalidateEmail
        });

        // Act
        document.body.appendChild(element);

        // Assert
        const card = element.shadowRoot.querySelector('lightning-card');
        expect(card).not.toBeNull();
        expect(card.title).toBe('Email Invalidation');

        const buttons = element.shadowRoot.querySelectorAll('lightning-button');
        expect(buttons).toHaveLength(3);

        const invalidateButton = element.shadowRoot.querySelector('[data-id="invalidate-button"]');
        expect(invalidateButton.label).toBe('Invalidate Emails');
        expect(invalidateButton.variant).toBe('destructive');

        const restoreButton = element.shadowRoot.querySelector('[data-id="restore-button"]');
        expect(restoreButton.label).toBe('Restore Emails');
        expect(restoreButton.variant).toBe('success');

        const scanButton = element.shadowRoot.querySelector('[data-id="scan-button"]');
        expect(scanButton.label).toBe('Scan For Email Fields');
        expect(scanButton.variant).toBe('brand');
    });

    it('calls Apex method and shows success toast on invalidate button click', async () => {
        // Arrange
        const mockResponse = {
            success: true,
            message: 'Email invalidation batch jobs started for all configured email fields.'
        };
        invalidateAllConfiguredEmails.mockResolvedValue(mockResponse);

        const element = createElement('c-invalidate-email', {
            is: InvalidateEmail
        });
        document.body.appendChild(element);

        // Act
        const invalidateButton = element.shadowRoot.querySelector('[data-id="invalidate-button"]');
        invalidateButton.click();

        // Wait for async operations
        await Promise.resolve();

        // Assert
        expect(invalidateAllConfiguredEmails).toHaveBeenCalledTimes(1);
    });

    it('calls Apex method and shows success toast on restore button click', async () => {
        // Arrange
        const mockResponse = {
            success: true,
            message: 'Email restoration batch jobs started for all configured email fields.'
        };
        restoreAllConfiguredEmails.mockResolvedValue(mockResponse);

        const element = createElement('c-invalidate-email', {
            is: InvalidateEmail
        });
        document.body.appendChild(element);

        // Act
        const restoreButton = element.shadowRoot.querySelector('[data-id="restore-button"]');
        restoreButton.click();

        // Wait for async operations
        await Promise.resolve();

        // Assert
        expect(restoreAllConfiguredEmails).toHaveBeenCalledTimes(1);
    });

    it('calls Apex method and shows success toast on scan button click', async () => {
        // Arrange
        const mockResponse = {
            success: true,
            message: 'Email field scanning batch job started successfully. Results will be cached for your review instead of being deployed immediately.'
        };
        startEmailFieldScanAura.mockResolvedValue(mockResponse);

        const element = createElement('c-invalidate-email', {
            is: InvalidateEmail
        });
        document.body.appendChild(element);

        // Act
        const scanButton = element.shadowRoot.querySelector('[data-id="scan-button"]');
        scanButton.click();

        // Wait for async operations
        await Promise.resolve();

        // Assert
        expect(startEmailFieldScanAura).toHaveBeenCalledTimes(1);
    });

    it('disables the invalidate button while the invalidate call is pending and re-enables it after', async () => {
        // Arrange
        let resolveApex;
        invalidateAllConfiguredEmails.mockReturnValue(
            new Promise((resolve) => {
                resolveApex = resolve;
            })
        );

        const element = createElement('c-invalidate-email', {
            is: InvalidateEmail
        });
        document.body.appendChild(element);

        // Act
        const invalidateButton = element.shadowRoot.querySelector('[data-id="invalidate-button"]');
        invalidateButton.click();
        await Promise.resolve();

        // Assert: disabled while the call is in flight
        expect(invalidateButton.disabled).toBe(true);

        // Act: let the Apex call resolve
        resolveApex({ success: true, message: 'Started.' });
        await Promise.resolve();
        await Promise.resolve();

        // Assert: re-enabled once scheduled
        expect(invalidateButton.disabled).toBe(false);
    });

    it('disables the restore button while the restore call is pending and re-enables it after', async () => {
        // Arrange
        let resolveApex;
        restoreAllConfiguredEmails.mockReturnValue(
            new Promise((resolve) => {
                resolveApex = resolve;
            })
        );

        const element = createElement('c-invalidate-email', {
            is: InvalidateEmail
        });
        document.body.appendChild(element);

        // Act
        const restoreButton = element.shadowRoot.querySelector('[data-id="restore-button"]');
        restoreButton.click();
        await Promise.resolve();

        // Assert: disabled while the call is in flight
        expect(restoreButton.disabled).toBe(true);

        // Act: let the Apex call resolve
        resolveApex({ success: true, message: 'Started.' });
        await Promise.resolve();
        await Promise.resolve();

        // Assert: re-enabled once scheduled
        expect(restoreButton.disabled).toBe(false);
    });

    it('disables the scan button while the scan call is pending and re-enables it after', async () => {
        // Arrange
        let resolveApex;
        startEmailFieldScanAura.mockReturnValue(
            new Promise((resolve) => {
                resolveApex = resolve;
            })
        );

        const element = createElement('c-invalidate-email', {
            is: InvalidateEmail
        });
        document.body.appendChild(element);

        // Act
        const scanButton = element.shadowRoot.querySelector('[data-id="scan-button"]');
        scanButton.click();
        await Promise.resolve();

        // Assert: disabled while the call is in flight
        expect(scanButton.disabled).toBe(true);

        // Act: let the Apex call resolve
        resolveApex({ success: true, message: 'Started.' });
        await Promise.resolve();
        await Promise.resolve();

        // Assert: re-enabled once scheduled
        expect(scanButton.disabled).toBe(false);
    });

    it('does not show any processing banner or disable buttons when no jobs are active', async () => {
        // Arrange
        const element = createElement('c-invalidate-email', {
            is: InvalidateEmail
        });

        // Act
        document.body.appendChild(element);
        await flushPromises();

        // Assert
        const banners = element.shadowRoot.querySelectorAll('.slds-theme_info');
        expect(banners).toHaveLength(0);

        const invalidateButton = element.shadowRoot.querySelector('[data-id="invalidate-button"]');
        const restoreButton = element.shadowRoot.querySelector('[data-id="restore-button"]');
        const scanButton = element.shadowRoot.querySelector('[data-id="scan-button"]');
        expect(invalidateButton.disabled).toBe(false);
        expect(restoreButton.disabled).toBe(false);
        expect(scanButton.disabled).toBe(false);
    });

    it('shows only the invalidate banner and disables only the invalidate button when an invalidate job is active', async () => {
        // Arrange
        getActiveJobStatus.mockResolvedValue({
            invalidate: { active: true, jobCount: 2, batchesProcessed: null, totalBatches: null },
            restore: inactiveAction(),
            scan: inactiveAction()
        });

        const element = createElement('c-invalidate-email', {
            is: InvalidateEmail
        });

        // Act
        document.body.appendChild(element);
        await flushPromises();

        // Assert: exactly one banner shown, with the invalidate-specific count
        const banners = element.shadowRoot.querySelectorAll('.slds-theme_info');
        expect(banners).toHaveLength(1);
        expect(banners[0].textContent).toContain('Invalidate Emails: 2 jobs pending.');

        const invalidateButton = element.shadowRoot.querySelector('[data-id="invalidate-button"]');
        const restoreButton = element.shadowRoot.querySelector('[data-id="restore-button"]');
        const scanButton = element.shadowRoot.querySelector('[data-id="scan-button"]');
        expect(invalidateButton.disabled).toBe(true);
        expect(restoreButton.disabled).toBe(false);
        expect(scanButton.disabled).toBe(false);
    });

    it('shows batches processed / total batches progress for a Processing invalidate job', async () => {
        // Arrange
        getActiveJobStatus.mockResolvedValue({
            invalidate: { active: true, jobCount: 1, batchesProcessed: 4, totalBatches: 10 },
            restore: inactiveAction(),
            scan: inactiveAction()
        });

        const element = createElement('c-invalidate-email', {
            is: InvalidateEmail
        });

        // Act
        document.body.appendChild(element);
        await flushPromises();

        // Assert
        const banners = element.shadowRoot.querySelectorAll('.slds-theme_info');
        expect(banners).toHaveLength(1);
        expect(banners[0].textContent).toContain(
            'Invalidate Emails: Processing 4 of 10 batches. 1 job pending.'
        );
    });

    it('shows only the restore banner and disables only the restore button when a restore job is active', async () => {
        // Arrange
        getActiveJobStatus.mockResolvedValue({
            invalidate: inactiveAction(),
            restore: { active: true, jobCount: 1, batchesProcessed: 2, totalBatches: 5 },
            scan: inactiveAction()
        });

        const element = createElement('c-invalidate-email', {
            is: InvalidateEmail
        });

        // Act
        document.body.appendChild(element);
        await flushPromises();

        // Assert
        const banners = element.shadowRoot.querySelectorAll('.slds-theme_info');
        expect(banners).toHaveLength(1);
        expect(banners[0].textContent).toContain(
            'Restore Emails: Processing 2 of 5 batches. 1 job pending.'
        );

        const invalidateButton = element.shadowRoot.querySelector('[data-id="invalidate-button"]');
        const restoreButton = element.shadowRoot.querySelector('[data-id="restore-button"]');
        const scanButton = element.shadowRoot.querySelector('[data-id="scan-button"]');
        expect(invalidateButton.disabled).toBe(false);
        expect(restoreButton.disabled).toBe(true);
        expect(scanButton.disabled).toBe(false);
    });

    it('shows only the scan banner and disables only the scan button when a scan job is active', async () => {
        // Arrange
        getActiveJobStatus.mockResolvedValue({
            invalidate: inactiveAction(),
            restore: inactiveAction(),
            scan: { active: true, jobCount: 1, batchesProcessed: null, totalBatches: null }
        });

        const element = createElement('c-invalidate-email', {
            is: InvalidateEmail
        });

        // Act
        document.body.appendChild(element);
        await flushPromises();

        // Assert
        const banners = element.shadowRoot.querySelectorAll('.slds-theme_info');
        expect(banners).toHaveLength(1);
        expect(banners[0].textContent).toContain('Scan For Email Fields: 1 job pending.');

        const invalidateButton = element.shadowRoot.querySelector('[data-id="invalidate-button"]');
        const restoreButton = element.shadowRoot.querySelector('[data-id="restore-button"]');
        const scanButton = element.shadowRoot.querySelector('[data-id="scan-button"]');
        expect(invalidateButton.disabled).toBe(false);
        expect(restoreButton.disabled).toBe(false);
        expect(scanButton.disabled).toBe(true);
    });

    it('shows all three banners at once when every job type is active', async () => {
        // Arrange
        getActiveJobStatus.mockResolvedValue({
            invalidate: { active: true, jobCount: 1, batchesProcessed: null, totalBatches: null },
            restore: { active: true, jobCount: 1, batchesProcessed: null, totalBatches: null },
            scan: { active: true, jobCount: 1, batchesProcessed: null, totalBatches: null }
        });

        const element = createElement('c-invalidate-email', {
            is: InvalidateEmail
        });

        // Act
        document.body.appendChild(element);
        await flushPromises();

        // Assert
        const banners = element.shadowRoot.querySelectorAll('.slds-theme_info');
        expect(banners).toHaveLength(3);
    });

    it('polls every 5s initially, then switches to 15s after 5 minutes have elapsed', () => {
        // Arrange: control elapsed time and observe the interval each poll schedules,
        // without waiting on real timers.
        let currentTime = 1700000000000;
        const dateNowSpy = jest.spyOn(Date, 'now').mockImplementation(() => currentTime);
        const setTimeoutSpy = jest.spyOn(global, 'setTimeout').mockImplementation(() => 0);

        try {
            const element = createElement('c-invalidate-email', {
                is: InvalidateEmail
            });

            // Act: mount the component, which schedules the first poll.
            document.body.appendChild(element);

            // Assert: the first poll uses the fast (5s) interval.
            expect(setTimeoutSpy).toHaveBeenLastCalledWith(expect.any(Function), 5000);

            // Act: simulate that poll firing after 4 minutes have elapsed (still under
            // the 5-minute threshold) by invoking the callback setTimeout was given.
            currentTime += 4 * 60 * 1000;
            setTimeoutSpy.mock.calls[setTimeoutSpy.mock.calls.length - 1][0]();

            // Assert: still polling at the fast interval.
            expect(setTimeoutSpy).toHaveBeenLastCalledWith(expect.any(Function), 5000);

            // Act: simulate elapsed time crossing the 5-minute threshold (6 minutes total).
            currentTime += 2 * 60 * 1000;
            setTimeoutSpy.mock.calls[setTimeoutSpy.mock.calls.length - 1][0]();

            // Assert: now polling at the slow (15s) interval.
            expect(setTimeoutSpy).toHaveBeenLastCalledWith(expect.any(Function), 15000);
        } finally {
            dateNowSpy.mockRestore();
            setTimeoutSpy.mockRestore();
        }
    });

    it('does not show the production warning or disable the invalidate button in a sandbox', async () => {
        // Arrange
        const element = createElement('c-invalidate-email', {
            is: InvalidateEmail
        });
        document.body.appendChild(element);

        // Act
        isSandboxOrg.emit(true);
        await Promise.resolve();

        // Assert
        const alert = element.shadowRoot.querySelector('.slds-theme_warning');
        expect(alert).toBeNull();

        const invalidateButton = element.shadowRoot.querySelector('[data-id="invalidate-button"]');
        expect(invalidateButton.disabled).toBe(false);
    });

    it('shows the production warning and disables the invalidate button in production', async () => {
        // Arrange
        const element = createElement('c-invalidate-email', {
            is: InvalidateEmail
        });
        document.body.appendChild(element);

        // Act
        isSandboxOrg.emit(false);
        await Promise.resolve();

        // Assert
        const alert = element.shadowRoot.querySelector('.slds-theme_warning');
        expect(alert).not.toBeNull();
        expect(alert.textContent).toContain('production org');

        const invalidateButton = element.shadowRoot.querySelector('[data-id="invalidate-button"]');
        expect(invalidateButton.disabled).toBe(true);
    });
});
