*   Allow to detach an attachment when record is not persisted

    *Jacopo Beschi*

*   Use libvips instead of ImageMagick to analyze images when `active_storage.variant_processor = vips`  

    *Breno Gazzola*

*   Add metadata value for presence of video channel in video blobs

    The `metadata` attribute of video blobs has a new boolean key named `video` that is set to
    `true` if the file has an video channel and `false` if it doesn't.

    *Breno Gazzola*

*   Deprecate usage of `purge` and `purge_later` from the association extension.

    *Jacopo Beschi*

*   Passing extra parameters in `ActiveStorage::Blob#url` to S3 Client

    This allows calls of `ActiveStorage::Blob#url` to have more interaction with
    the S3 Presigner, enabling, amongst other options, custom S3 domain URL
    Generation.

    ```ruby
    blob = ActiveStorage::Blob.last

    blob.url # => https://<bucket-name>.s3.<region>.amazonaws.com/<key>
    blob.url(virtual_host: true) # => # => https://<bucket-name>/<key>
    ```

    *josegomezr*

*   Allow setting a `Cache-Control` on files uploaded to GCS.

    ```yaml
    gcs:
      service: GCS
      ...
      cache_control: "public, max-age=3600"
    ```
    *maleblond*

*   The parameters sent to `ffmpeg` for generating a video preview image are now
    configurable under `config.active_storage.video_preview_arguments`.

    *Brendon Muir*

*   The ActiveStorage video previewer will now use scene change detection to generate
    better preview images (rather than the previous default of using the first frame
    of the video). This change requires FFmpeg v3.4+.

    *Jonathan Hefner*

*   Add support for ActiveStorage expiring URLs.

    ```ruby
    rails_blob_path(user.avatar, disposition: "attachment", expires_in: 30.minutes)

    <%= image_tag rails_blob_path(user.avatar.variant(resize: "100x100"), expires_in: 30.minutes) %>
    ```

    If you want to set default expiration time for ActiveStorage URLs throughout your application, set `config.active_storage.urls_expire_in`.

    *aki77*

*   Allow to purge an attachment when record is not persisted for `has_many_attached`

    *Jacopo Beschi*

*   Add `with_all_variant_records` method to eager load all variant records on an attachment at once.
    `with_attached_image` scope now eager loads variant records if using variant tracking.

    *Alex Ghiculescu*

*   Add metadata value for presence of audio channel in video blobs

    The `metadata` attribute of video blobs has a new boolean key named `audio` that is set to
    `true` if the file has an audio channel and `false` if it doesn't.

    *Breno Gazzola*

*   Adds analyzer for audio files.

    *Breno Gazzola*

*   Respect Active Record's primary_key_type in Active Storage migrations

    *fatkodima*

*   Allow `expires_in` for ActiveStorage signed ids.

    *aki77*

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
