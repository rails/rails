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

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activestorage/CHANGELOG.md) for previous changes.
