*   `ActiveStorage::Blob#open` can now be used without passing a block, like `Tempfile.open`. When using this form the
    returned temporary file must be unlinked manually.

    *Bart de Water*

*   `ActiveStorage::Blob#purge` won't delete blob records when their file deletion on the service fails.
    This prevents dangling files on the storage.

    For example, GCS sometimes fails with `Google::Cloud::UnavailableError`. In such cases, we want to keep the blob
    record intact so that we can retry deletion later.

    *Peter Toth*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/activestorage/CHANGELOG.md) for previous changes.
