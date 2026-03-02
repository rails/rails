*   Restore ADC when signing URLs with IAM for GCS

    ADC was previously used for automatic authorization when signing URLs with IAM.
    Now it is again, but the auth client is memoized so that new credentials are only
    requested when the current ones expire. Other auth methods can now be used
    instead by setting the authorization on `ActiveStorage::Service::GCSService#iam_client`.

    ```ruby
    ActiveStorage::Blob.service.iam_client.authorization = Google::Auth::ImpersonatedServiceAccountCredentials.new(options)
    ```

    This is safer than setting `Google::Apis::RequestOptions.default.authorization`
    because it only applies to Active Storage and does not affect other Google API
    clients.

    *Justin Malčić*

*   Move responsibility for checksums storage service

    The storage service should implement calculating and
    validating checksums.

    *Matt Pasquini*

*   Analyze attachments before validation

    Attachment metadata (width, height, duration, etc.) is now available for
    model validations:

    ```ruby
    class User < ApplicationRecord
      has_one_attached :avatar

      validate :validate_avatar_dimensions, if: -> { avatar.attached? }

      def validate_avatar_dimensions
        if avatar.metadata[:width] < 200 || avatar.metadata[:height] < 200
          errors.add(:avatar, "must be at least 200x200")
        end
      end
    end
    ```

    Configure when analysis is performed:

    * `analyze: :immediately` (default in 8.2) - Analyze before validation
    * `analyze: :later` - Analyze after upload from local IO or via background job
    * `analyze: :lazily` - Skip automatic analysis; analyze on-demand

    ```ruby
    has_one_attached :document, analyze: :later
    has_many_attached :files, analyze: :lazily

    # Or set the global default:
    config.active_storage.analyze = :later
    ```

    Direct uploads bypass the server so the file isn't locally available
    for analysis. In this case, `:immediately` falls back to `:later`,
    analyzing via background job after upload completes. Metadata isn't
    available for validation; validate on the client side instead.

    *Jeremy Daer*

*   Use local files for immediate variant processing and analysis

    `process: :immediately` variants and blob analysis use local files
    directly instead of re-downloading after upload.

    Applies when attaching uploadable io, not when attaching an existing Blob.

    *Jeremy Daer*

*   Introduce `ActiveStorage::Attachment` upload callbacks

    `after_upload` fires after an attachment's blob is uploaded, enabling
    analysis and processing to run deterministically rather than assuming
    after-commit callback execution ordering.

    ```ruby
    ActiveStorage::Attachment.after_upload do
      # Your custom logic here
    end
    ```

    *Jeremy Daer*

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
