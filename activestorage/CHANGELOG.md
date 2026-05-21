*   Fix `MirrorService#mirror` raising `ActiveStorage::IntegrityError` when
    mirroring without a checksum (e.g., `track_variants: false`).

    *Denis Savchuk*

*   Preserve attachment changes when converting record to another class using STI.

    *fatkodima*

*   Correct unexpected behavior resulting from dependent: :purge when using
    has_one_attached or has_many_attached. Fixes #36423.

    *Mark Oveson*

*   Define `as_json` on `ActiveStorage::Attached::One` and `ActiveStorage::Attached::Many`.

    The proxies hold a back-reference to the owning record in `@record`. Without an explicit
    `as_json`, the default `Object#as_json` fall back serialized `instance_values`, which made
    `record.to_json` recurse infinitely whenever the attached name collided with a model
    attribute (e.g. an `ignored_columns` column brought back by `select('*')`).

    `Attached::One#as_json` now returns the attachment record's JSON when attached and `nil`
    otherwise. `Attached::Many#as_json` returns the attachment records' JSON as an array.

    *Renxiang Cai*

*   Fix Rails hanging when generating video previews

    When Rails runs in a background process group, ffmpeg's attempt to configure the terminal for
    interactive input would send SIGTTOU to the Rails process, suspending it indefinitely.

    Fixed by explicitly passing /dev/null to ffmpeg's stdin.

    *Jonathan del Strother*


## Rails 8.1.3 (March 24, 2026) ##

*   Fix `ActiveStorage::Blob` content type predicate methods to handle `nil`.

    *Daichi KUDO*


## Rails 8.1.2.1 (March 23, 2026) ##

*   Filter user supplied metadata in DirectUploadController

    [CVE-2026-33173]

    *Jean Boussier*

*   Configurable maxmimum streaming chunk size

    Makes sure that byte ranges for blobs don't exceed 100mb by default.
    Content ranges that are too big can result in denial of service.

    [CVE-2026-33174]

    *Gannon McGibbon*

*   Limit range requests to a single range

    [CVE-2026-33658]

    *Jean Boussier*


*   Prevent path traversal in `DiskService`.

    `DiskService#path_for` now raises an `InvalidKeyError` when passed keys with dot segments (".",
    ".."), or if the resolved path is outside the storage root directory.

    `#path_for` also now consistently raises `InvalidKeyError` if the key is invalid in any way, for
    example containing null bytes or having an incompatible encoding. Previously, the exception
    raised may have been `ArgumentError` or `Encoding::CompatibilityError`.

    `DiskController` now explicitly rescues `InvalidKeyError` with appropriate HTTP status codes.

    [CVE-2026-33195]

    *Mike Dalessio*

*   Prevent glob injection in `DiskService#delete_prefixed`.

    Escape glob metacharacters in the resolved path before passing to `Dir.glob`.

    Note that this change breaks any existing code that is relying on `delete_prefixed` to expand
    glob metacharacters. This change presumes that is unintended behavior (as other storage services
    do not respect these metacharacters).

    [CVE-2026-33202]

    *Mike Dalessio*


## Rails 8.1.2 (January 08, 2026) ##

*   Restore ADC when signing URLs with IAM for GCS

    ADC was previously used for automatic authorization when signing URLs with IAM.
    Now it is again, but the auth client is memoized so that new credentials are only
    requested when the current ones expire. Other auth methods can now be used
    instead by setting the authorization on `ActiveStorage::Service::GCSService#iam_client`.

    ```ruby
    ActiveStorage::Blob.service.iam_client.authorization = Google::Auth::ImpersonatedServiceAccountCredentials.new(options)
    ```

    This is safer than setting `Google::Apis::RequestOptions.default.authorization`
    because it only applies to Active Storage and does not affect other Google API
    clients.

    *Justin Malčić*


## Rails 8.1.1 (October 28, 2025) ##

*   No changes.


## Rails 8.1.0 (October 22, 2025) ##

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

*   A Blob will no longer autosave associated Attachment.

    This fixes an issue where a record with an attachment would have
    its dirty attributes reset, preventing your `after commit` callbacks
    on that record to behave as expected.

    Note that this change doesn't require any changes on your application
    and is supposed to be internal. Active Storage Attachment will continue
    to be autosaved (through a different relation).

    *Edouard-chin*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/activestorage/CHANGELOG.md) for previous changes.
