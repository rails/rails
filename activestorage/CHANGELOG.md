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

*   `ActiveStorage::Blob#purge` won't delete blob records when their file deletion on the service fails.
    This prevents dangling files on the storage.

    For example, GCS sometimes fails with `Google::Cloud::UnavailableError`. In such cases, we want to keep the blob
    record intact so that we can retry deletion later.

    *Peter Toth*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/activestorage/CHANGELOG.md) for previous changes.
