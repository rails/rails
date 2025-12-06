*   Dispatch `direct-upload:success` with `blob` and `hiddenInput`

    The `direct-upload:success` event is dispatched after the final
    `direct-upload:progress` and before `direct-upload:end`. The `blob` is the
    response from `ActiveStorage::DirectUploadsController#create`. The `hiddenInput`
    is the `<input type="hidden">` element created by the upload.

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
