public without sharing class InvalidateEmailBatch implements Database.Batchable<SObject>, Database.Stateful {
  private String objectName;
  private Set<String> fields;
  private Integer recordsProcessed = 0;
  private Integer recordsUpdated = 0;
  private List<String> errors = new List<String>();

  // Constructor for processing a specific object and field
  public InvalidateEmailBatch(String objectName, Set<String> fields) {
    this.objectName = objectName;
    this.fields = fields;
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    String query;

    // Create a comma spliced string of fields.
    String preppedFields = 'Id';
    Boolean hasUnfilterableField = false;
    String whereClause = ' WHERE Id!=\'\' AND (';
    for (String f : fields) {
      preppedFields = preppedFields + ',' + f;
      if (isFilterable(objectName, f)) {
        whereClause = whereClause + ' ' + f + '<>\'\' OR';
      } else {
        // Long Text Area/Rich Text fields (e.g. a multi-email field like
        // Product2.Venue_Emails__c) can't be referenced in a WHERE clause,
        // so we can't narrow the query using them. Fall back to processing
        // every record for this object; execute() skips ones that don't
        // actually need a change.
        hasUnfilterableField = true;
      }
    }
    whereClause = whereClause + ' Id=\'\')';

    if (String.isNotBlank(objectName) && preppedFields != 'Id') {
      // Process specific object and field
      query =
        'SELECT ' +
        preppedFields +
        ' FROM ' +
        objectName +
        (hasUnfilterableField ? ' WHERE Id!=\'\'' : whereClause);
    }

    System.debug('InvalidateEmailBatch query: ' + query);
    return Database.getQueryLocator(query);
  }

  public void execute(Database.BatchableContext context, List<SObject> scope) {
    List<SObject> recordsToUpdate = new List<SObject>();
    String invalidationText = InvalidateEmailSettings.getInvalidationText();

    Map<String, Boolean> fieldIsTextMap = new Map<String, Boolean>();
    for (String emailField : fields) {
      fieldIsTextMap.put(emailField, isTextField(objectName, emailField));
    }

    for (SObject record : scope) {
      for (String emailField : fields) {
        try {
          System.debug('Processing record: ' + record);
          String currentValue = (String) record.get(emailField);
          if (String.isNotBlank(currentValue)) {
            String invalidatedValue = invalidateValue(
              currentValue,
              invalidationText,
              fieldIsTextMap.get(emailField)
            );

            if (invalidatedValue != null) {
              record.put(emailField, invalidatedValue);
              recordsToUpdate.add(record);
              recordsProcessed++;
            }
          }
        } catch (Exception e) {
          errors.add(
            'Error processing record ' + record.Id + ': ' + e.getMessage()
          );
          System.debug('Error processing record: ' + e.getMessage());
        }
      }
    }

    if (!recordsToUpdate.isEmpty()) {
      try {
        Database.SaveResult[] results = Database.update(recordsToUpdate, false);

        for (Integer i = 0; i < results.size(); i++) {
          if (results[i].isSuccess()) {
            recordsUpdated++;
          } else {
            for (Database.Error error : results[i].getErrors()) {
              errors.add(
                'Error updating record ' +
                  recordsToUpdate[i].Id +
                  ': ' +
                  error.getMessage()
              );
            }
          }
        }
      } catch (Exception e) {
        errors.add('Batch update error: ' + e.getMessage());
        System.debug('Batch update error: ' + e.getMessage());
      }
    }
  }

  public void finish(Database.BatchableContext context) {
    System.debug('InvalidateEmailBatch completed');
    System.debug('Records processed: ' + recordsProcessed);
    System.debug('Records updated: ' + recordsUpdated);

    if (!errors.isEmpty()) {
      System.debug('Errors encountered: ' + errors.size());
      for (String error : errors) {
        System.debug('Error: ' + error);
      }
    }

    // Send completion email to the user who started the batch
    AsyncApexJob job = [
      SELECT
        Id,
        Status,
        NumberOfErrors,
        JobItemsProcessed,
        TotalJobItems,
        CreatedBy.Email
      FROM AsyncApexJob
      WHERE Id = :context.getJobId()
    ];

    if (String.isNotBlank(job.CreatedBy.Email)) {
      try {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ job.CreatedBy.Email });
        email.setSubject('Email Invalidation Batch Job Completed');

        String emailBody = 'The email invalidation batch job has completed.\n\n';
        emailBody += 'Job Status: ' + job.Status + '\n';
        emailBody += 'Total Job Items: ' + job.TotalJobItems + '\n';
        emailBody += 'Job Items Processed: ' + job.JobItemsProcessed + '\n';
        emailBody += 'Records Updated: ' + recordsUpdated + '\n';

        if (job.NumberOfErrors > 0 || !errors.isEmpty()) {
          emailBody += 'Number of Errors: ' + job.NumberOfErrors + '\n';
          if (!errors.isEmpty()) {
            emailBody += '\nDetailed Errors:\n';
            for (String error : errors) {
              emailBody += '- ' + error + '\n';
            }
          }
        }

        email.setPlainTextBody(emailBody);
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
      } catch (Exception e) {
        System.debug('Error sending completion email: ' + e.getMessage());
      }
    }
  }

  // Custom exception used to block email invalidation outside of sandboxes
  public class ProductionOrgException extends Exception {
  }

  // Matches individual email addresses within a field's value. Text/TextArea
  // fields (e.g. Product2.Venue_Emails__c) may hold more than one address
  // separated by commas, semicolons, or whitespace; this lets us invalidate
  // each address in place without disturbing the delimiters between them.
  public static final Pattern EMAIL_PATTERN = Pattern.compile(
    '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'
  );

  // Native Email fields always hold a single address, so the whole value can
  // be treated as one email. Text/TextArea fields have no such guarantee and
  // are treated as potentially holding a delimited list of addresses.
  public static Boolean isTextField(String objectName, String fieldApiName) {
    Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectName);
    if (sObjType == null) {
      return false;
    }

    Schema.SObjectField field = sObjType.getDescribe()
      .fields.getMap()
      .get(fieldApiName);
    if (field == null) {
      return false;
    }

    Schema.DisplayType fieldType = field.getDescribe().getType();
    return fieldType == Schema.DisplayType.STRING ||
      fieldType == Schema.DisplayType.TEXTAREA;
  }

  // Long Text Area/Rich Text fields (and a handful of other field types)
  // can't be referenced in a SOQL WHERE clause. Callers that build a query
  // filter around a configured field need to check this first.
  public static Boolean isFilterable(String objectName, String fieldApiName) {
    Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectName);
    if (sObjType == null) {
      return true;
    }

    Schema.SObjectField field = sObjType.getDescribe()
      .fields.getMap()
      .get(fieldApiName);
    if (field == null) {
      return true;
    }

    return field.getDescribe().isFilterable();
  }

  // Appends the invalidation text to the value. For a plain Email field the
  // whole value is a single address. For a text field, every email address
  // found in the value is invalidated individually, leaving delimiters and
  // any surrounding text untouched. Returns null when no change is needed.
  public static String invalidateValue(
    String value,
    String invalidationText,
    Boolean isTextField
  ) {
    if (!isTextField) {
      return value.endsWith(invalidationText)
        ? null
        : value + invalidationText;
    }

    Matcher matcher = EMAIL_PATTERN.matcher(value);
    Boolean changed = false;
    String result = '';
    Integer lastEnd = 0;

    while (matcher.find()) {
      result += value.substring(lastEnd, matcher.start());
      String emailMatch = matcher.group();
      if (!emailMatch.endsWith(invalidationText)) {
        emailMatch += invalidationText;
        changed = true;
      }
      result += emailMatch;
      lastEnd = matcher.end();
    }
    result += value.substring(lastEnd);

    return changed ? result : null;
  }

  // Static method to process all configured email fields from custom metadata
  public static void invalidateAllConfiguredEmails() {
    if (!InvalidateEmailSettings.isSandbox()) {
      throw new ProductionOrgException(
        'Email invalidation is only allowed in Sandbox environments.'
      );
    }

    // Fetch the metadata and extract the field information.
    Map<String, Email_Invalidator_Fields__mdt> emailFields = Email_Invalidator_Fields__mdt.getAll();
    Map<String, Set<String>> objectsWithFields = getFieldDetails(emailFields);

    // Create batches for each object
    // TODO: Protect against the 60 batch limit.
    for (String objectName : objectsWithFields.keySet()) {
      InvalidateEmailBatch batch = new InvalidateEmailBatch(
        objectName,
        objectsWithFields.get(objectName)
      );
      Database.executeBatch(batch, 200);
    }
  }

  // Helper method to extract the object and field information
  // from the metadata in a consistent form. The records use
  // 'DurableIds' which are names for standard fields, and Ids
  // for custom fields. We need names for everything.
  public static Map<String, Set<String>> getFieldDetails(
    Map<String, Email_Invalidator_Fields__mdt> fieldMetaList
  ) {
    Map<String, Set<String>> objectFields = new Map<String, Set<String>>();
    Email_Invalidator_Fields__mdt currentField;
    String objectApiName;
    List<String> fieldDurableIds = new List<String>();

    // Prep the map we'll return with object names as keys, and extra
    // the Durableids from the metadata to query in one shot.
    for (String invalidatorKey : fieldMetaList.keySet()) {
      currentField = fieldMetaList.get(invalidatorKey);

      fieldDurableIds.add(currentField.Field_Name__c);
    }

    // Now get all the EntityParticles based on the list of DurableIds
    for (EntityParticle ep : [
      SELECT
        QualifiedApiName,
        DataType,
        EntityDefinition.QualifiedApiName,
        DurableId
      FROM EntityParticle
      WHERE DurableId IN :fieldDurableIds
    ]) {
      System.debug(ep);
      objectApiName = ep.EntityDefinition.QualifiedApiName;
      if (!objectFields.containsKey(objectApiName)) {
        objectFields.put(objectApiName, new Set<String>());
      }

      objectFields.get(objectApiName).add(ep.QualifiedApiName);
    }

    return objectFields;
  }
}
