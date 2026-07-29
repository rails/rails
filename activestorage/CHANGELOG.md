## Rails 8.0.5.1 (July 29, 2026) ##

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


## Rails 8.0.5 (March 24, 2026) ##

*   Fix `ActiveStorage::Blob` content type predicate methods to handle `nil`.

    *Daichi KUDO*


## Rails 8.0.4.1 (March 23, 2026) ##

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


## Rails 8.0.4 (October 28, 2025) ##

*   No changes.


## Rails 8.0.3 (September 22, 2025) ##

*   Address deprecation of `Aws::S3::Object#upload_stream` in `ActiveStorage::Service::S3Service`.

    *Joshua Young*

*   Fix `config.active_storage.touch_attachment_records` to work with eager loading.

    *fatkodima*


## Rails 8.0.2.1 (August 13, 2025) ##

*   Remove dangerous transformations

    [CVE-2025-24293]

    *Zack Deveau*

## Rails 8.0.2 (March 12, 2025) ##

*   A Blob will no longer autosave associated Attachment.

    This fixes an issue where a record with an attachment would have
    its dirty attributes reset, preventing your `after commit` callbacks
    on that record to behave as expected.

    Note that this change doesn't require any changes on your application
    and is supposed to be internal. Active Storage Attachment will continue
    to be autosaved (through a different relation).

    *Edouard-chin*


## Rails 8.0.1 (December 13, 2024) ##

*   No changes.


## Rails 8.0.0.1 (December 10, 2024) ##

*   No changes.


## Rails 8.0.0 (November 07, 2024) ##

*   No changes.


## Rails 8.0.0.rc2 (October 30, 2024) ##

*   No changes.


## Rails 8.0.0.rc1 (October 19, 2024) ##

*   No changes.


## Rails 8.0.0.beta1 (September 26, 2024) ##

*   Deprecate `ActiveStorage::Service::AzureStorageService`.

    *zzak*

*   Improve `ActiveStorage::Filename#sanitized` method to handle special characters more effectively.
    Replace the characters `"*?<>` with `-` if they exist in the Filename to match the Filename convention of Win OS.

    *Luong Viet Dung(Martin)*

*   Improve InvariableError, UnpreviewableError and UnrepresentableError message.

    Include Blob ID and content_type in the messages.

    *Petrik de Heus*

*   Mark proxied files as `immutable` in their Cache-Control header

    *Nate Matykiewicz*


Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/activestorage/CHANGELOG.md) for previous changes.
