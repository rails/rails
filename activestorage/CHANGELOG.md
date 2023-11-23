*   Prevent `ActiveStorage::Blob#preview` to generate a variant if an empty variation is passed.
    Calls to `#url`, `#key` or `#download` will now use the original preview
    image instead of generating a variant with the exact same dimensions.

    *Chedli Bourguiba*

*   Allow accepting `service` as a proc as well in `has_one_attached` and `has_many_attached`.

    *Yogesh Khater*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activestorage/CHANGELOG.md) for previous changes.
