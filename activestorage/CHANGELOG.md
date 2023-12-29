*   Deprecate `ActiveStorage::Service::AzureStorageService`.

    *zzak*

*   Active Storage can be configured by `STORAGE_URL` environment variable

    The following cases are currently supported:

    ```
    disk://my/root/path
    s3://access_key_id:secret_access_key@us-east-1/your-bucket
    gcs://path/to/gcs.keyfile@your_project/your-bucket
    ```

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
