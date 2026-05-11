*   Correct unexpected behavior resulting from dependent: :purge when using
    has_one_attached or has_many_attached. Fixes #36423.

    *Mark Oveson*

*   Fix Rails hanging when generating video previews

    When Rails runs in a background process group, ffmpeg's attempt to configure the terminal for
    interactive input would send SIGTTOU to the Rails process, suspending it indefinitely.

    Fixed by explicitly passing /dev/null to ffmpeg's stdin.

    *Jonathan del Strother*


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
