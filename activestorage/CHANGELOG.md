## Rails 8.0.0.rc1 (October 19, 2024) ##

*   No changes.


## Rails 8.0.0.beta1 (September 26, 2024) ##

*   Allow setting object download options in S3 service.

    Object download options are used in `S3Service#download`, `S3Service#download_chunk`, `S3Service#compose` and `S3Service#exist?`.

    ```yml
    s3:
      service: S3
      download:
        sse_customer_algorithm: ""
        sse_customer_key: ""
        sse_customer_key_md5: ""
    ```

    *Lovro Bikić*

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
