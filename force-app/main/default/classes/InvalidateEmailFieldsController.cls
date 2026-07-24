public with sharing class InvalidateEmailFieldsController {
  // Wrapper exposing the metadata record alongside the human-readable
  // object/field names resolved from their DurableIds.
  public class InvalidateEmailField {
    @AuraEnabled
    public String Id;
    @AuraEnabled
    public String Label;
    @AuraEnabled
    public String DeveloperName;
    @AuraEnabled
    public String ObjectName;
    @AuraEnabled
    public String FieldName;
  }

  @AuraEnabled(cacheable=true)
  public static List<InvalidateEmailField> getInvalidateEmailFields() {
    Map<String, Email_Invalidator_Fields__mdt> emailFieldsMap = Email_Invalidator_Fields__mdt.getAll();

    Set<String> objectDurableIds = new Set<String>();
    Set<String> fieldDurableIds = new Set<String>();
    for (Email_Invalidator_Fields__mdt field : emailFieldsMap.values()) {
      objectDurableIds.add(field.Object__c);
      fieldDurableIds.add(field.Field_Name__c);
    }

    // Object__c and Field_Name__c are MetadataRelationship fields that
    // store DurableIds. For standard objects/fields the DurableId already
    // matches the API name, but for custom ones it is a raw Salesforce Id.
    // Resolve both to their QualifiedApiName so the UI never shows a raw Id.
    Map<String, String> objectNamesByDurableId = new Map<String, String>();
    for (EntityDefinition ed : [
      SELECT DurableId, QualifiedApiName
      FROM EntityDefinition
      WHERE DurableId IN :objectDurableIds
    ]) {
      objectNamesByDurableId.put(ed.DurableId, ed.QualifiedApiName);
    }

    Map<String, String> fieldNamesByDurableId = new Map<String, String>();
    for (EntityParticle ep : [
      SELECT DurableId, QualifiedApiName
      FROM EntityParticle
      WHERE DurableId IN :fieldDurableIds
    ]) {
      fieldNamesByDurableId.put(ep.DurableId, ep.QualifiedApiName);
    }

    List<InvalidateEmailField> results = new List<InvalidateEmailField>();
    for (Email_Invalidator_Fields__mdt field : emailFieldsMap.values()) {
      InvalidateEmailField wrapper = new InvalidateEmailField();
      wrapper.Id = field.Id;
      wrapper.Label = field.Label;
      wrapper.DeveloperName = field.DeveloperName;
      wrapper.ObjectName = objectNamesByDurableId.containsKey(field.Object__c)
        ? objectNamesByDurableId.get(field.Object__c)
        : field.Object__c;
      wrapper.FieldName = fieldNamesByDurableId.containsKey(field.Field_Name__c)
        ? fieldNamesByDurableId.get(field.Field_Name__c)
        : field.Field_Name__c;
      results.add(wrapper);
    }

    return results;
  }

  @AuraEnabled
  public static string getCustomMetadataObjectPrefix() {
    return Email_Invalidator_Fields__mdt.sobjecttype.getDescribe()
      .getKeyPrefix();
  }
}
