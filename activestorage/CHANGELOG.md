*   Prevent `ActiveRecord::StrictLoadingViolationError` when strict loading is
    enabled and the variant of an Active Storage preview has already been
    processed (for example, by calling `ActiveStorage::Preview#url`).

    *Jonathan Hefner*

*   Fix `preprocessed: true` option for named variants of previewable files.

    *Nico Wenterodt*

*   Allow accepting `service` as a proc as well in `has_one_attached` and `has_many_attached`.

    *Yogesh Khater*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activestorage/CHANGELOG.md) for previous changes.
