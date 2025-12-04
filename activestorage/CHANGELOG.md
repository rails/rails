*   Fix `LogSubscriber` to log error messages instead of success messages when storage operations fail with exceptions
    (e.g., network errors uploading to S3).

    Previously, operations like upload, download, and delete would log success messages (e.g., "Uploaded file to key: xxx")
    even when they failed, because `ActiveSupport::Notifications` publishes events in an `ensure` block. Now the
    `LogSubscriber` checks for exceptions in the event payload and logs appropriate error messages with the exception
    class and message (e.g., "Failed to upload file to key: xxx (Net::OpenTimeout: execution expired)").

    *Felipe Raul*

*   `ActiveStorage::Blob#open` can now be used without passing a block, like `Tempfile.open`. When using this form the
    returned temporary file must be unlinked manually.

    *Bart de Water*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/activestorage/CHANGELOG.md) for previous changes.
