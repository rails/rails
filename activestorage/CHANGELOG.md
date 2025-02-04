*   Support additional file checksum algorithms in Azure Adapter

    Add support for CRC64 to S3 service for
    file integrity checking.
    Add default_digest_algorithm configuration allowing selection of default
    checksum algorithm for service. Keep default value as MD5

    *Matt Pasquini*

*   Support additional file checksum algorithms in GCS Adapter

    Add support for CRC32c to S3 service for
    file integrity checking.
    Add default_digest_algorithm configuration allowing selection of default
    checksum algorithm for service. Keep default value as MD5

    *Matt Pasquini*

*   Support additional file checksum algorithms in S3 Adapter

    Add support for CRC32, CRC32c, SHA1, SHA256, and CRC64NVMe to S3 service for
    file integrity checking.
    Add default_digest_algorithm configuration allowing selection of default
    checksum algorithm for service. Keep default value as MD5

    *Matt Pasquini*

*   Introduce ActiveSupport::Checksum

    Refactor to support file additional integrity check algorithm in services

    *Matt Pasquini*

*   Delegate `ActiveStorage::Filename#to_str` to `#to_s`

    Supports checking String equality:

    ```ruby
    filename = ActiveStorage::Filename.new("file.txt")
    filename == "file.txt" # => true
    filename in "file.txt" # => true
    "file.txt" == filename # => true
    ```

    *Sean Doyle*

*   Add support for fallback MD5 implementation

    Automatically degrade to using the slower `Digest::MD5` implementation if `OpenSSL::Digest::MD5`
    is found to be disabled because of OpenSSL FIPS mode.

    *Matt Pasquini*, *Jean Boussier*

*   A Blob will no longer autosave associated Attachment.

    This fixes an issue where a record with an attachment would have
    its dirty attributes reset, preventing your `after commit` callbacks
    on that record to behave as expected.

    Note that this change doesn't require any changes on your application
    and is supposed to be internal. Active Storage Attachment will continue
    to be autosaved (through a different relation).

    *Edouard-chin*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/activestorage/CHANGELOG.md) for previous changes.
