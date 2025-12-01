*   `ActiveStorage::Blob#open` can now be used without passing a block, like `Tempfile.open`. When using this form the
    returned temporary file must be unlinked manually.

    *Bart de Water*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/activestorage/CHANGELOG.md) for previous changes.
