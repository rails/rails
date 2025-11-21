*   Control downloaded filename encoded into `Content-Disposition` header
    through `:filename` query parameter nested within `:disposition`

    ```ruby
    # before - might not download file to `avatar.png` depending on browser
    link_to "Download", rails_blob_path(user.avatar, disposition: "attachment"), download: "avatar.png")

    # after
    link_to "Download", rails_blob_path(user.avatar, disposition: { disposition: "attachment", filename: "avatar.png" })
    ```

    *Sean Doyle*

*   `ActiveStorage::Blob#open` can now be used without passing a block, like `Tempfile.open`. When using this form the
    returned temporary file must be unlinked manually.

    *Bart de Water*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/activestorage/CHANGELOG.md) for previous changes.
