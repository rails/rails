*   Add structured events for Active Storage:
    - `active_storage.service_upload`
    - `active_storage.service_download`
    - `active_storage.service_streaming_download`
    - `active_storage.preview`
    - `active_storage.service_delete`
    - `active_storage.service_delete_prefixed`
    - `active_storage.service_exist`
    - `active_storage.service_url`
    - `active_storage.service_mirror`

    *Gannon McGibbon*

*   Allow analyzers and variant transformer to be fully configurable

    ```ruby
    # ActiveStorage.analyzers can be set to an empty array:
    config.active_storage.analyzers = []
    # => ActiveStorage.analyzers = []

    # or use custom analyzer:
    config.active_storage.analyzers = [ CustomAnalyzer ]
    # => ActiveStorage.analyzers = [ CustomAnalyzer ]
    ```

    If no configuration is provided, it will use the default analyzers.

    You can also disable variant processor to remove warnings on startup about missing gems.

    ```ruby
    config.active_storage.variant_processor = :disabled
    ```

    *zzak*, *Alexandre Ruban*

## Rails 8.1.0.beta1 (September 04, 2025) ##

*   Remove deprecated `:azure` storage service.

    *Rafael Mendonça França*

*   Remove unnecessary calls to the GCP metadata server.

    Calling Google::Auth.get_application_default triggers an explicit call to
    the metadata server - given it was being called for significant number of
    file operations, it can lead to considerable tail latencies and even metadata
    server overloads. Instead, it's preferable (and significantly more efficient)
    that applications use:

    ```ruby
    Google::Apis::RequestOptions.default.authorization = Google::Auth.get_application_default(...)
    ```

    In the cases applications do not set that, the GCP libraries automatically determine credentials.

    This also enables using credentials other than those of the associated GCP
    service account like when using impersonation.

    *Alex Coomans*

*   Direct upload progress accounts for server processing time.

    *Jeremy Daer*

*   Delegate `ActiveStorage::Filename#to_str` to `#to_s`

    Supports checking String equality:

    ```ruby
    filename = ActiveStorage::Filename.new("file.txt")
    filename == "file.txt" # => true
    filename in "file.txt" # => true
    "file.txt" == filename # => true
    ```

    *Sean Doyle*

*   Add support for alternative MD5 implementation through `config.active_storage.checksum_implementation`.

    Also automatically degrade to using the slower `Digest::MD5` implementation if `OpenSSL::Digest::MD5`
    is found to be disabled because of OpenSSL FIPS mode.

    *Matt Pasquini*, *Jean Boussier*

*   A Blob will no longer autosave associated Attachment.

    This fixes an issue where a record with an attachment would have
    its dirty attributes reset, preventing your `after commit` callbacks
    on that record to behave as expected.

    Note that this change doesn't require any changes on your application
    and is supposed to be internal. Active Storage Attachment will continue
    to be autosaved (through a different relation).

    *Edouard-chin*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/activestorage/CHANGELOG.md) for previous changes.
