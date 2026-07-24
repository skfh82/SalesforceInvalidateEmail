/**
 * Utility class for retrieving Email Invalidator settings from custom metadata
 */
public without sharing class InvalidateEmailSettings {
  private static String invalidationText;

  /**
   * Gets the invalidation text from custom metadata
   * @return String The invalidation text to append to email addresses
   */
  public static String getInvalidationText() {
    if (invalidationText == null) {
      try {
        Email_Invalidator_Settings__mdt setting = Email_Invalidator_Settings__mdt.getInstance(
          'Invalidation_Text'
        );
        if (setting != null && String.isNotBlank(setting.Setting_Value__c)) {
          invalidationText = setting.Setting_Value__c;
        } else {
          // Fallback to default value if custom metadata is not found
          invalidationText = '.invalid';
          System.debug(
            'Warning: Invalidation_Text custom metadata not found, using default value: ' +
            invalidationText
          );
        }
      } catch (Exception e) {
        // Fallback to default value if there's any error
        invalidationText = '.invalid';
        System.debug(
          'Error retrieving invalidation text from custom metadata: ' +
            e.getMessage() +
            ', using default value: ' +
            invalidationText
        );
      }
    }
    return invalidationText;
  }

  /**
   * Clears the cached invalidation text (useful for testing and after settings updates)
   */
  public static void clearCache() {
    invalidationText = null;
  }

  /**
   * Checks whether the running org is a sandbox (or other non-production org).
   * Used to prevent the email invalidation batch from ever running in production.
   * @return Boolean True if the current org is a sandbox
   */
  public static Boolean isSandbox() {
    return [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
  }
}
