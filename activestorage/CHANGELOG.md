*   Saving attachment(s) to a record returns the blob/blobs object

    Previously, saving attachments did not return the blob/blobs that
    were attached. Now, saving attachments to a record with `#attach`
    method returns the blob or array of blobs that were attached to
    the record. If it fails to save the attachment(s), then it returns
    `false`.

    *Ghouse Mohamed*

*   Don't stream responses in redirect mode

    Previously, both redirect mode and proxy mode streamed their
    responses which caused a new thread to be created, and could end
    up leaking connections in the connection pool. But since redirect
    mode doesn't actually send any data, it doesn't need to be
    streamed.

    *Luke Lau*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/activestorage/CHANGELOG.md) for previous changes.
