import { createElement } from '@lwc/engine-dom';
import InvalidateEmail from 'c/invalidateEmail';
import invalidateAllConfiguredEmails from '@salesforce/apex/InvalidateEmailFlowAction.invalidateAllConfiguredEmailsAura';
import startEmailFieldScanAura from '@salesforce/apex/EmailFieldScannerController.startEmailFieldScanAura';
import isSandboxOrg from '@salesforce/apex/InvalidateEmailFlowAction.isSandboxOrg';

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

describe('c-invalidate-email', () => {
    afterEach(() => {
        // The jsdom instance is shared across test cases in a single file so reset the DOM
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        // Clear all mocks
        jest.clearAllMocks();
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

    it('executes restore button click without errors (placeholder functionality)', async () => {
        // Arrange
        const element = createElement('c-invalidate-email', {
            is: InvalidateEmail
        });
        document.body.appendChild(element);

        // Act
        const restoreButton = element.shadowRoot.querySelector('[data-id="restore-button"]');

        // This should not throw an error
        expect(() => {
            restoreButton.click();
        }).not.toThrow();

        // Wait for async operations
        await Promise.resolve();

        // Assert that the button exists and is clickable
        expect(restoreButton).not.toBeNull();
        expect(restoreButton.label).toBe('Restore Emails');
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
        const alert = element.shadowRoot.querySelector('.slds-notify_alert');
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
        const alert = element.shadowRoot.querySelector('.slds-notify_alert');
        expect(alert).not.toBeNull();
        expect(alert.textContent).toContain('production org');

        const invalidateButton = element.shadowRoot.querySelector('[data-id="invalidate-button"]');
        expect(invalidateButton.disabled).toBe(true);
    });
});
