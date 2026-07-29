## Rails 7.2.3.2 (July 29, 2026) ##

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

## Rails 7.2.3.1 (March 23, 2026) ##

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


## Rails 7.2.3 (October 28, 2025) ##

*   Fix `config.active_storage.touch_attachment_records` to work with eager loading.

    *fatkodima*

*   A Blob will no longer autosave associated Attachment.

    This fixes an issue where a record with an attachment would have
    its dirty attributes reset, preventing your `after commit` callbacks
    on that record to behave as expected.

    Note that this change doesn't require any changes on your application
    and is supposed to be internal. Active Storage Attachment will continue
    to be autosaved (through a different relation).

    *Edouard-chin*


## Rails 7.2.2.2 (August 13, 2025) ##

*   Remove dangerous transformations

    [CVE-2025-24293]

    *Zack Deveau*


## Rails 7.2.2.1 (December 10, 2024) ##

*   No changes.


## Rails 7.2.2 (October 30, 2024) ##

*   No changes.


## Rails 7.2.1.2 (October 23, 2024) ##

*   No changes.


## Rails 7.2.1.1 (October 15, 2024) ##

*   No changes.


## Rails 7.2.1 (August 22, 2024) ##

*   No changes.


## Rails 7.2.0 (August 09, 2024) ##

*   Remove deprecated `config.active_storage.silence_invalid_content_types_warning`.

    *Rafael Mendonça França*

*   Remove deprecated `config.active_storage.replace_on_assign_to_many`.

    *Rafael Mendonça França*

*   Add support for custom `key` in `ActiveStorage::Blob#compose`.

    *Elvin Efendiev*

*   Add `image/webp` to `config.active_storage.web_image_content_types` when `load_defaults "7.2"`
    is set.

    *Lewis Buckley*

*   Fix JSON-encoding of `ActiveStorage::Filename` instances.

    *Jonathan del Strother*

*   Fix N+1 query when fetching preview images for non-image assets.

    *Aaron Patterson & Justin Searls*

*   Fix all Active Storage database related models to respect
    `ActiveRecord::Base.table_name_prefix` configuration.

    *Chedli Bourguiba*

*   Fix `ActiveStorage::Representations::ProxyController` not returning the proper
    preview image variant for previewable files.

    *Chedli Bourguiba*

*   Fix `ActiveStorage::Representations::ProxyController` to proxy untracked
    variants.

    *Chedli Bourguiba*

*   When using the `preprocessed: true` option, avoid enqueuing transform jobs
    for blobs that are not representable.

    *Chedli Bourguiba*

*   Prevent `ActiveStorage::Blob#preview` to generate a variant if an empty variation is passed.

    Calls to `#url`, `#key` or `#download` will now use the original preview
    image instead of generating a variant with the exact same dimensions.

    *Chedli Bourguiba*

*   Process preview image variant when calling `ActiveStorage::Preview#processed`.

    For example, `attached_pdf.preview(:thumb).processed` will now immediately
    generate the full-sized preview image and the `:thumb` variant of it.
    Previously, the `:thumb` variant would not be generated until a further call
    to e.g. `processed.url`.

    *Chedli Bourguiba* and *Jonathan Hefner*

*   Prevent `ActiveRecord::StrictLoadingViolationError` when strict loading is
    enabled and the variant of an Active Storage preview has already been
    processed (for example, by calling `ActiveStorage::Preview#url`).

    *Jonathan Hefner*

*   Fix `preprocessed: true` option for named variants of previewable files.

    *Nico Wenterodt*

*   Allow accepting `service` as a proc as well in `has_one_attached` and `has_many_attached`.

    *Yogesh Khater*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activestorage/CHANGELOG.md) for previous changes.
