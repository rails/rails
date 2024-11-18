*   Control downloaded filename encoded into `Content-Disposition` header
    through `:filename` query parameter nested within `:disposition`

    ```ruby
    # before - might not download file to `avatar.png` depending on browser
    link_to "Download", rails_blob_path(user.avatar, disposition: "attachment"), download: "avatar.png")

    # after
    link_to "Download", rails_blob_path(user.avatar, disposition: { disposition: "attachment", filename: "avatar.png" })
    ```

    *Sean Doyle*

*   Introduce immediate variants that are generated immediately on attachment

    The new `process` option determines when variants are created:

    - `:lazily` (default) - Variants are created dynamically when requested
    - `:later` (replaces `preprocessed: true`) - Variants are created after attachment, in a background job
    - `:immediately` (new) - Variants are created along with the attachment

    ```ruby
    has_one_attached :avatar do |attachable|
      attachable.variant :thumb, resize_to_limit: [100, 100], process: :immediately
    end
    ```

    The `preprocessed: true` option is deprecated in favor of `process: :later`.

    *Tom Rossi*

*   Make `Variant#processed?` and `VariantWithRecord#processed?` public so apps can check variant generation status.

    *Tom Rossi*

*   `ActiveStorage::Blob#open` can now be used without passing a block, like `Tempfile.open`. When using this form the
    returned temporary file must be unlinked manually.

    *Bart de Water*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/activestorage/CHANGELOG.md) for previous changes.
