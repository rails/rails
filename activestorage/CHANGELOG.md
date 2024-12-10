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
