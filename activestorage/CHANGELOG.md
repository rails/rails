## Rails 8.1.3.1 (July 29, 2026) ##

*   Disable libvips's unfuzzed image loaders and savers.

    libvips flags some of its loaders and savers as "unfuzzed" or "untrusted", meaning they are only
    safe for trusted content. Active Storage will call `Vips.block_untrusted(true)` to disable them
    while booting. An application that needs a specific loader or saver may re-enable it in an
    initializer.

    This is a breaking change for applications that process image types with an unfuzzed loader or
    saver. Variant transformation of BMP, ICO, and PSD attachments will raise `Vips::Error`, and
    analysis of these and other types such as SVG, JPEG XL, JPEG 2000, and Netpbm will no longer
    record `width` and `height`. Requesting an unfuzzed output format, typically FITS, JXL, or
    anything delegated to ImageMagick, will also raise `Vips::Error`. Attaching, storing, and
    downloading are unchanged.

    An application seeing `Vips::Error` raised during image transformation may wish to remove the
    affected content types from `config.active_storage.variable_content_types` in an initializer.
    Active Storage will then treat those attachments as not variable and will not generate variants
    for them. This most often matters to an application that transforms images during a request
    rather than in a background job, where the failure surfaces as an error response instead of a
    failed job.

    ```ruby
    Rails.application.config.active_storage.variable_content_types -=
      %w[ image/bmp image/vnd.microsoft.icon image/vnd.adobe.photoshop ]
    ```

    Applications using the `:mini_magick` variant processor will see no change in how their
    attachments are processed, but the loaders and savers will be disabled process-wide whenever
    ruby-vips is installed, and the version requirements below will still apply. Such an application
    may remove ruby-vips from its Gemfile to avoid both.

    The minimum supported version of libvips is now 8.13, and the minimum supported version of
    ruby-vips is now 2.2.1. These are the earliest versions that are capable of disabling untrusted
    operations. When ruby-vips is installed and either minimum is not met, Active Storage will raise
    a `RuntimeError` while booting rather than run in an unsecurable environment.

    [GHSA-xr9x-r78c-5hrm]
    [CVE-2026-66066]

    *Mike Dalessio*


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
