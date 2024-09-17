*   Add support for alternative MD5 implementation through `config.active_storage.checksum_implementation`.

    Also automatically degrade to using the slower `Digest::MD5` implementation if `OpenSSL::Digest::MD5`
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

*   Add `active_storage_direct_uploads_controller` load hook

    Issue #34961

    Allows users to restrict direct uploads with their own authentication and/or rate limiting.

    ```ruby
    ActiveSupport.on_load :active_storage_direct_uploads_controller do
      before_action :authenticate_user!
      rate_limit to: 10, within: 3.minutes
    end
    ```

    *juanvqz*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/activestorage/CHANGELOG.md) for previous changes.
