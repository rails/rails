*   When attaching blobs by their signed ids, you can now configure to attach with `:private_id` or `:blob_id`.

    This is important due to a security vulnerability described in [#41413](https://github.com/rails/rails/issues/41413) where
    a malicious user could attach another user's blob to their own record. The recommended approach is to use `:private_id` which
    won't be visible to any other user.

    For a smooth migration there's an intermediate setting `:private_id_with_fallback` where both signature purposes will
    be accepted for a short period of time.

    *Santiago Bartesaghi*, *Juan E. Roig*, *brunvez*

*   Allow to purge an attachment when record is not persisted for `has_one_attached`

    *Jacopo Beschi*

*   Add a load hook called `active_storage_variant_record` (providing `ActiveStorage::VariantRecord`)
    to allow for overriding aspects of the `ActiveStorage::VariantRecord` class. This makes
    `ActiveStorage::VariantRecord` consistent with `ActiveStorage::Blob` and `ActiveStorage::Attachment`
    that already have load hooks.

    *Brendon Muir*

*   `ActiveStorage::PreviewError` is raised when a previewer is unable to generate a preview image.

    *Alex Robbin*

*   Add `ActiveStorage::Streaming` module that can be included in a controller to get access to `#send_blob_stream`,
    which wraps the new `ActionController::Base#send_stream` method to stream a blob from cloud storage:

    ```ruby
    class MyPublicBlobsController < ApplicationController
      include ActiveStorage::SetBlob, ActiveStorage::Streaming

      def show
        http_cache_forever(public: true) do
          send_blob_stream @blob, disposition: params[:disposition]
        end
      end
    end
    ```

    *DHH*

*   Add ability to use pre-defined variants.

    ```ruby
    class User < ActiveRecord::Base
      has_one_attached :avatar do |attachable|
        attachable.variant :thumb, resize: "100x100"
        attachable.variant :medium, resize: "300x300", monochrome: true
      end
    end

    class Gallery < ActiveRecord::Base
      has_many_attached :photos do |attachable|
        attachable.variant :thumb, resize: "100x100"
        attachable.variant :medium, resize: "300x300", monochrome: true
      end
    end

    <%= image_tag user.avatar.variant(:thumb) %>
    ```

    *fatkodima*

*   After setting `config.active_storage.resolve_model_to_route = :rails_storage_proxy`
    `rails_blob_path` and `rails_representation_path` will generate proxy URLs by default.

    *Ali Ismayilov*

*   Declare `ActiveStorage::FixtureSet` and `ActiveStorage::FixtureSet.blob` to
    improve fixture integration

    *Sean Doyle*

Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/activestorage/CHANGELOG.md) for previous changes.
