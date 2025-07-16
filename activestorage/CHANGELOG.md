*   Direct upload progress accounts for server processing time.

    *Jeremy Daer*

*   Delegate `ActiveStorage::Filename#to_str` to `#to_s`

    Supports checking String equality:

    ```ruby
    filename = ActiveStorage::Filename.new("file.txt")
    filename == "file.txt" # => true
    filename in "file.txt" # => true
    "file.txt" == filename # => true
    ```

    *Sean Doyle*

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

*   Allow passing a custom key prefix during direct upload.

    You can now pass a `data-key` with a prefix like `uploads/<uuid>/<uuid>/` in a file input, and Active Storage will automatically append a secure token to generate the final key.

    Example:

    ```erb
    <%= form.file_field :file, direct_upload: true, data: { key: "uploads/#{current_user.id}/#{SecureRandom.uuid}/" } %>
    ```

    This enables more structured and predictable object paths when uploading files.

    *Himanshu Kale*


Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/activestorage/CHANGELOG.md) for previous changes.
