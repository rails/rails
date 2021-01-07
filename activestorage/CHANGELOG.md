*   Add `:storage_sas_token` and `:storage_blob_host` options to `AzureStorage` service.

    Valid sets of options include:
      *   Storage account name and key: `:storage_account_name` and `:storage_access_key` required
      *   Storage account name and SAS token: `:storage_account_name` and `:storage_sas_token` required
      *   Blob host and SAS token: `:storage_blob_host` and `:storage_sas_token` required. Blob host needs to be a service endpoint or hostname. It's up to user to ensure the SAS token is suitable for the service

    Adds support for more use cases already supported in the `azure_storage_blob` gem.

    *TheMasterCado*

Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/activestorage/CHANGELOG.md) for previous changes.
