## Rails 7.0.8.4 (June 04, 2024) ##

*   No changes.


## Rails 7.0.8.3 (May 17, 2024) ##

*   No changes.


## Rails 7.0.8.2 (May 16, 2024) ##

*   No changes.


## Rails 7.0.8.1 (February 21, 2024) ##

*   Disables the session in `ActiveStorage::Blobs::ProxyController`
    and `ActiveStorage::Representations::ProxyController`
    in order to allow caching by default in some CDNs as CloudFlare

    Fixes #44136

    *Bruno Prieto*

## Rails 7.0.8 (September 09, 2023) ##

*   No changes.


## Rails 7.0.7.2 (August 22, 2023) ##

*   No changes.


## Rails 7.0.7.1 (August 22, 2023) ##

*   No changes.


## Rails 7.0.7 (August 09, 2023) ##

*   No changes.


## Rails 7.0.6 (June 29, 2023) ##

*   Fix retrieving rotation value from FFmpeg on version 5.0+.

    In FFmpeg version 5.0+ the rotation value has been removed from tags.
    Instead the value can be found in side_data_list. Along with
    this update it's possible to have values of -90, -270 to denote the video
    has been rotated.

    *Haroon Ahmed*


## Rails 7.0.5.1 (June 26, 2023) ##

*   No changes.


## Rails 7.0.5 (May 24, 2023) ##

*   No changes.


## Rails 7.0.4.3 (March 13, 2023) ##

*   No changes.


## Rails 7.0.4.2 (January 24, 2023) ##

*   No changes.


## Rails 7.0.4.1 (January 17, 2023) ##

*   No changes.


## Rails 7.0.4 (September 09, 2022) ##

*   Fixes proxy downloads of files over 5MiB

    Previously, trying to view and/or download files larger than 5mb stored in
    services like S3 via proxy mode could return corrupted files at around
    5.2mb or cause random halts in the download. Now,
    `ActiveStorage::Blobs::ProxyController` correctly handles streaming these
    larger files from the service to the client without any issues.

    Fixes #44679

    *Felipe Raul*

## Rails 7.0.3.1 (July 12, 2022) ##

*   No changes.


## Rails 7.0.3 (May 09, 2022) ##

*   Don't stream responses in redirect mode

    Previously, both redirect mode and proxy mode streamed their
    responses which caused a new thread to be created, and could end
    up leaking connections in the connection pool. But since redirect
    mode doesn't actually send any data, it doesn't need to be
    streamed.

    *Luke Lau*

## Rails 7.0.2.4 (April 26, 2022) ##

*   No changes.


## Rails 7.0.2.3 (March 08, 2022) ##

*   Added image transformation validation via configurable allow-list.

    Variant now offers a configurable allow-list for
    transformation methods in addition to a configurable deny-list for arguments.

    [CVE-2022-21831]


## Rails 7.0.2.2 (February 11, 2022) ##

*   No changes.

## Rails 7.0.2.1 (February 11, 2022) ##

*   No changes.


## Rails 7.0.2 (February 08, 2022) ##

*   Revert the ability to pass `service_name` param to `DirectUploadsController` which was introduced
    in 7.0.0.

    That change caused a lot of problems to upgrade Rails applications so we decided to remove it
    while in work in a more backwards compatible implementation.

    *Gannon McGibbon*

*   Allow applications to opt out of precompiling Active Storage JavaScript assets.

    *jlestavel*


## Rails 7.0.1 (January 06, 2022) ##

*   No changes.


## Rails 7.0.0 (December 15, 2021) ##

*   Support transforming empty-ish `has_many_attached` value into `[]` (e.g. `[""]`).

    ```ruby
    @user.highlights = [""]
    @user.highlights # => []
    ```

    *Sean Doyle*


## Rails 7.0.0.rc3 (December 14, 2021) ##

*   No changes.


## Rails 7.0.0.rc2 (December 14, 2021) ##

*   No changes.

## Rails 7.0.0.rc1 (December 06, 2021) ##

*   `Add ActiveStorage::Blob.compose` to concatenate multiple blobs.

    *Gannon McGibbon*

*   Setting custom metadata on blobs are now persisted to remote storage.

    *joshuamsager*

*   Support direct uploads to multiple services.

    *Dmitry Tsepelev*

*   Invalid default content types are deprecated

    Blobs created with content_type `image/jpg`, `image/pjpeg`, `image/bmp`, `text/javascript` will now produce
    a deprecation warning, since these are not valid content types.

    These content types will be removed from the defaults in Rails 7.1.

    You can set `config.active_storage.silence_invalid_content_types_warning = true` to dismiss the warning.

    *Alex Ghiculescu*

## Rails 7.0.0.alpha2 (September 15, 2021) ##

*   No changes.


## Rails 7.0.0.alpha1 (September 15, 2021) ##

*   Emit Active Support instrumentation events from Active Storage analyzers.

    Fixes #42930

    *Shouichi Kamiya*

*   Add support for byte range requests

    *Tom Prats*

*   Attachments can be deleted after their association is no longer defined.

    Fixes #42514

    *Don Sisco*

*   Make `vips` the default variant processor for new apps.

    See the upgrade guide for instructions on converting from `mini_magick` to `vips`. `mini_magick` is
    not deprecated, existing apps can keep using it.

    *Breno Gazzola*

*   Deprecate `ActiveStorage::Current.host` in favor of `ActiveStorage::Current.url_options` which accepts
    a host, protocol and port.

    *Santiago Bartesaghi*

*   Allow using [IAM](https://cloud.google.com/storage/docs/access-control/signed-urls) when signing URLs with GCS.

    ```yaml
    gcs:
      service: GCS
      ...
      iam: true
    ```

    *RRethy*

*   OpenSSL constants are now used for Digest computations.

    *Dirkjan Bussink*

*   Deprecate `config.active_storage.replace_on_assign_to_many`. Future versions of Rails
    will behave the same way as when the config is set to `true`.

    *Santiago Bartesaghi*

*   Remove deprecated methods: `build_after_upload`, `create_after_upload!` in favor of `create_and_upload!`,
    and `service_url` in favor of `url`.

    *Santiago Bartesaghi*

*   Add support of `strict_loading_by_default` to `ActiveStorage::Representations` controllers.

    *Anton Topchii*, *Andrew White*

*   Allow to detach an attachment when record is not persisted.

    *Jacopo Beschi*

*   Use libvips instead of ImageMagick to analyze images when `active_storage.variant_processor = vips`.

    *Breno Gazzola*

*   Add metadata value for presence of video channel in video blobs.

    The `metadata` attribute of video blobs has a new boolean key named `video` that is set to
    `true` if the file has an video channel and `false` if it doesn't.

    *Breno Gazzola*

*   Deprecate usage of `purge` and `purge_later` from the association extension.

    *Jacopo Beschi*

*   Passing extra parameters in `ActiveStorage::Blob#url` to S3 Client.

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

*   Allow to purge an attachment when record is not persisted for `has_many_attached`.

    *Jacopo Beschi*

*   Add `with_all_variant_records` method to eager load all variant records on an attachment at once.
    `with_attached_image` scope now eager loads variant records if using variant tracking.

    *Alex Ghiculescu*

*   Add metadata value for presence of audio channel in video blobs.

    The `metadata` attribute of video blobs has a new boolean key named `audio` that is set to
    `true` if the file has an audio channel and `false` if it doesn't.

    *Breno Gazzola*

*   Adds analyzer for audio files.

    *Breno Gazzola*

*   Respect Active Record's primary_key_type in Active Storage migrations.

    *fatkodima*

*   Allow `expires_in` for ActiveStorage signed ids.

    *aki77*

*   Allow to purge an attachment when record is not persisted for `has_one_attached`.

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
    improve fixture integration.

    *Sean Doyle*


Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/activestorage/CHANGELOG.md) for previous changes.
