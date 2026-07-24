import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getInvalidateEmailFields from '@salesforce/apex/InvalidateEmailFieldsController.getInvalidateEmailFields';
import getInvalidateEmailMetadataPrefix from '@salesforce/apex/InvalidateEmailFieldsController.getCustomMetadataObjectPrefix';


const COLUMNS = [
  {
    label: 'Label',
    fieldName: 'Label',
    type: 'text',
    sortable: true
  },
  {
    label: 'Developer Name',
    fieldName: 'DeveloperName',
    type: 'text',
    sortable: true
  },
  {
    label: 'Object',
    fieldName: 'Object__c',
    type: 'text',
    sortable: true
  },
  {
    label: 'Field Name',
    fieldName: 'Field_Name__c',
    type: 'text',
    sortable: true
  },
  {
    type: 'action',
    typeAttributes: {
      rowActions: [
        {
          label: 'Edit',
          name: 'edit'
        }
      ]
    }
  }
];

export default class InvalidateEmailFieldsList extends NavigationMixin(LightningElement) {
  columns = COLUMNS;
  invalidateEmailFields = [];
  error;
  isLoading = true;

  @wire(getInvalidateEmailFields)
  wiredInvalidateEmailFields({ error, data }) {
    if (data) {
      // Convert map to list
      this.invalidateEmailFields = Object.values(data);
      this.error = undefined;
      this.isLoading = false;
    } else if (error) {
      this.error = error.body?.message || 'Unknown error occurred';
      this.invalidateEmailFields = [];
      this.isLoading = false;
    }
  }

  get hasData() {
    return this.invalidateEmailFields && this.invalidateEmailFields.length > 0;
  }

  handleRowAction(event) {
    const actionName = event.detail.action.name;
    const row = event.detail.row;

    if (actionName === 'edit') {
      // Navigate to the record page for editing
      this[NavigationMixin.Navigate]({
        type: 'standard__recordPage',
        attributes: {
          recordId: row.Id,
          objectApiName: 'Email_Invalidator_Fields__mdt',
          actionName: 'edit'
        }
      });
    }
  }

  async handleNewRecord() {
    const metadataPrefix = await getInvalidateEmailMetadataPrefix();
    // Navigate to the Custom Metadata Type management page
    this[NavigationMixin.Navigate]({
      type: 'standard__webPage',
      attributes: {
        url: '/lightning/setup/CustomMetadata/page?address=%2F' + metadataPrefix + '%3Fsetupid%3DCustomMetadata'
      }
    });
  }
}
