*   Add ability to use pre-defined variants.

    ```ruby
    class User < ActiveRecord::Base
      has_one_attached :avatar do |attachable|
        attachable.variant :thumb, resize: "100x100"
        attachable.variant :medium, resize: "300x300", monochrome: true
      end
    end

    class Gallery < ActiveRecord::Base
      has_many_attached :photos do |attachable|
        attachable.variant :thumb, resize: "100x100"
        attachable.variant :medium, resize: "300x300", monochrome: true
      end
    end

    <%= image_tag user.avatar.variant(:thumb) %>
    ```

    *fatkodima*

*   After setting `config.active_storage.resolve_model_to_route = :rails_storage_proxy`
    `rails_blob_path` and `rails_representation_path` will generate proxy URLs by default.

    *Ali Ismayilov*

*   Declare `ActiveStorage::FixtureSet` and `ActiveStorage::FixtureSet.blob` to
    improve fixture integration

    *Sean Doyle*
    
*   Add `:storage_sas_token` and `:storage_blob_host` options to `AzureStorage` service.

    Valid sets of options include:
      *   Storage account name and key: `:storage_account_name` and `:storage_access_key` required
      *   Storage account name and SAS token: `:storage_account_name` and `:storage_sas_token` required
      *   Blob host and SAS token: `:storage_blob_host` and `:storage_sas_token` required. Blob host needs to be a service endpoint. It's up to user to ensure the SAS token is suitable for the service

    Adds support for more use cases already supported in the `azure_storage_blob` gem.

    *TheMasterCado*

Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/activestorage/CHANGELOG.md) for previous changes.
