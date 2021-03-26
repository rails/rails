## Rails 6.1.3.1 (March 26, 2021) ##

*  Marcel is upgraded to version 1.0.0 to avoid a dependency on GPL-licensed
   mime types data.

   *George Claghorn*


## Rails 6.1.3 (February 17, 2021) ##

*   No changes.


## Rails 6.1.2.1 (February 10, 2021) ##

*   No changes.


## Rails 6.1.2 (February 09, 2021) ##

*   No changes.


## Rails 6.1.1 (January 07, 2021) ##

*   Fix S3 multipart uploads when threshold is larger than file.

    *Matt Muller*


## Rails 6.1.0 (December 09, 2020) ##

*   Change default queue name of the analysis (`:active_storage_analysis`) and
    purge (`:active_storage_purge`) jobs to be the job adapter's default (`:default`).

    *Rafael Mendonça França*

*   Implement `strict_loading` on ActiveStorage associations.

    *David Angulo*

*   Remove deprecated support to pass `:combine_options` operations to `ActiveStorage::Transformers::ImageProcessing`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveStorage::Transformers::MiniMagickTransformer`.

    *Rafael Mendonça França*

*   Remove deprecated `config.active_storage.queue`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveStorage::Downloading`.

    *Rafael Mendonça França*

*   Add per-environment configuration support

    *Pietro Moro*

*   The Poppler PDF previewer renders a preview image using the original
    document's crop box rather than its media box, hiding print margins. This
    matches the behavior of the MuPDF previewer.

    *Vincent Robert*

*   Touch parent model when an attachment is purged.

    *Víctor Pérez Rodríguez*

*   Files can now be served by proxying them from the underlying storage service
    instead of redirecting to a signed service URL. Use the
    `rails_storage_proxy_path` and `_url` helpers to proxy an attached file:

    ```erb
    <%= image_tag rails_storage_proxy_path(@user.avatar) %>
    ```

    To proxy by default, set `config.active_storage.resolve_model_to_route`:

    ```ruby
    # Proxy attached files instead.
    config.active_storage.resolve_model_to_route = :rails_storage_proxy
    ```

    ```erb
    <%= image_tag @user.avatar %>
    ```

    To redirect to a signed service URL when the default file serving strategy
    is set to proxying, use the `rails_storage_redirect_path` and `_url` helpers:

    ```erb
    <%= image_tag rails_storage_redirect_path(@user.avatar) %>
    ```

    *Jonathan Fleckenstein*

*   Add `config.active_storage.web_image_content_types` to allow applications
    to add content types (like `image/webp`) in which variants can be processed,
    instead of letting those images be converted to the fallback PNG format.

    *Jeroen van Haperen*

*   Add support for creating variants of `WebP` images out of the box.

    *Dino Maric*

*   Only enqueue analysis jobs for blobs with non-null analyzer classes.

    *Gannon McGibbon*

*   Previews are created on the same service as the original blob.

    *Peter Zhu*

*   Remove unused `disposition` and `content_type` query parameters for `DiskService`.

    *Peter Zhu*

*   Use `DiskController` for both public and private files.

    `DiskController` is able to handle multiple services by adding a
    `service_name` field in the generated URL in `DiskService`.

    *Peter Zhu*

*   Variants are tracked in the database to avoid existence checks in the storage service.

    *George Claghorn*

*   Deprecate `service_url` methods in favour of `url`.

    Deprecate `Variant#service_url` and `Preview#service_url` to instead use
    `#url` method to be consistent with `Blob`.

    *Peter Zhu*

*   Permanent URLs for public storage blobs.

    Services can be configured in `config/storage.yml` with a new key
    `public: true | false` to indicate whether a service holds public
    blobs or private blobs. Public services will always return a permanent URL.

    Deprecates `Blob#service_url` in favor of `Blob#url`.

    *Peter Zhu*

*   Make services aware of configuration names.

    *Gannon McGibbon*

*   The `Content-Type` header is set on image variants when they're uploaded to third-party storage services.

    *Kyle Ribordy*

*   Allow storage services to be configured per attachment.

    ```ruby
    class User < ActiveRecord::Base
      has_one_attached :avatar, service: :s3
    end

    class Gallery < ActiveRecord::Base
      has_many_attached :photos, service: :s3
    end
    ```

    *Dmitry Tsepelev*

*   You can optionally provide a custom blob key when attaching a new file:

    ```ruby
    user.avatar.attach key: "avatars/#{user.id}.jpg",
      io: io, content_type: "image/jpeg", filename: "avatar.jpg"
    ```

    Active Storage will store the blob's data on the configured service at the provided key.

    *George Claghorn*

*   Replace `Blob.create_after_upload!` with `Blob.create_and_upload!` and deprecate the former.

    `create_after_upload!` has been removed since it could lead to data
    corruption by uploading to a key on the storage service which happened to
    be already taken. Creating the record would then correctly raise a
    database uniqueness exception but the stored object would already have
    overwritten another. `create_and_upload!` swaps the order of operations
    so that the key gets reserved up-front or the uniqueness error gets raised,
    before the upload to a key takes place.

    *Julik Tarkhanov*

*   Set content disposition in direct upload using `filename` and `disposition` parameters to `ActiveStorage::Service#headers_for_direct_upload`.

    *Peter Zhu*

*   Allow record to be optionally passed to blob finders to make sharding
    easier.

    *Gannon McGibbon*

*   Switch from `azure-storage` gem to `azure-storage-blob` gem for Azure service.

    *Peter Zhu*

*   Add `config.active_storage.draw_routes` to disable Active Storage routes.

    *Gannon McGibbon*

*   Image analysis is skipped if ImageMagick returns an error.

    `ActiveStorage::Analyzer::ImageAnalyzer#metadata` would previously raise a
    `MiniMagick::Error`, which caused persistent `ActiveStorage::AnalyzeJob`
    failures. It now logs the error and returns `{}`, resulting in no metadata
    being added to the offending image blob.

    *George Claghorn*

*   Method calls on singular attachments return `nil` when no file is attached.

    Previously, assuming the following User model, `user.avatar.filename` would
    raise a `Module::DelegationError` if no avatar was attached:

    ```ruby
    class User < ApplicationRecord
      has_one_attached :avatar
    end
    ```

    They now return `nil`.

    *Matthew Tanous*

*   The mirror service supports direct uploads.

    New files are directly uploaded to the primary service. When a
    directly-uploaded file is attached to a record, a background job is enqueued
    to copy it to each secondary service.

    Configure the queue used to process mirroring jobs by setting
    `config.active_storage.queues.mirror`. The default is `:active_storage_mirror`.

    *George Claghorn*

*   The S3 service now permits uploading files larger than 5 gigabytes.

    When uploading a file greater than 100 megabytes in size, the service
    transparently switches to [multipart uploads](https://docs.aws.amazon.com/AmazonS3/latest/dev/mpuoverview.html)
    using a part size computed from the file's total size and S3's part count limit.

    No application changes are necessary to take advantage of this feature. You
    can customize the default 100 MB multipart upload threshold in your S3
    service's configuration:

    ```yaml
    production:
      service: s3
      access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
      secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
      region: us-east-1
      bucket: my-bucket
      upload:
        multipart_threshold: <%= 250.megabytes %>
    ```

    *George Claghorn*


Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/activestorage/CHANGELOG.md) for previous changes.
