## Rails 6.0.6.1 (January 17, 2023) ##

*   No changes.


## Rails 6.0.6 (September 09, 2022) ##

*   No changes.


## Rails 6.0.5.1 (July 12, 2022) ##

*   No changes.


## Rails 6.0.5 (May 09, 2022) ##

*   No changes.


## Rails 6.0.4.8 (April 26, 2022) ##

*   No changes.


## Rails 6.0.4.7 (March 08, 2022) ##

*   Added image transformation validation via configurable allow-list.
    
    Variant now offers a configurable allow-list for
    transformation methods in addition to a configurable deny-list for arguments.
    
    [CVE-2022-21831]


## Rails 6.0.4.6 (February 11, 2022) ##

*   No changes.


## Rails 6.0.4.5 (February 11, 2022) ##

*   No changes.


## Rails 6.0.4.4 (December 15, 2021) ##

*   No changes.


## Rails 6.0.4.3 (December 14, 2021) ##

*   No changes.


## Rails 6.0.4.2 (December 14, 2021) ##

*   No changes.


## Rails 6.0.4.1 (August 19, 2021) ##

*   No changes.


## Rails 6.0.4 (June 15, 2021) ##

*   The Poppler PDF previewer renders a preview image using the original
    document's crop box rather than its media box, hiding print margins. This
    matches the behavior of the MuPDF previewer.

    *Vincent Robert*


## Rails 6.0.3.7 (May 05, 2021) ##

*   No changes.


## Rails 6.0.3.6 (March 26, 2021) ##

*   Marcel is upgraded to version 1.0.0 to avoid a dependency on GPL-licensed
    mime types data.

    *George Claghorn*


## Rails 6.0.3.5 (February 10, 2021) ##

*   No changes.


## Rails 6.0.3.4 (October 07, 2020) ##

*   No changes.


## Rails 6.0.3.3 (September 09, 2020) ##

*   No changes.


## Rails 6.0.3.2 (June 17, 2020) ##

*   No changes.


## Rails 6.0.3.1 (May 18, 2020) ##

*   [CVE-2020-8162] Include Content-Length in signature for ActiveStorage direct upload


## Rails 6.0.3 (May 06, 2020) ##

*   No changes.


## Rails 6.0.2.2 (March 19, 2020) ##

*   No changes.


## Rails 6.0.2.1 (December 18, 2019) ##

*   No changes.


## Rails 6.0.2 (December 13, 2019) ##

*   No changes.


## Rails 6.0.1 (November 5, 2019) ##

*   `ActiveStorage::AnalyzeJob`s are discarded on `ActiveRecord::RecordNotFound` errors.

    *George Claghorn*

*   Blobs are recorded in the database before being uploaded to the service.
    This fixes that generated blob keys could silently collide, leading to
    data loss.

    *Julik Tarkhanov*


## Rails 6.0.0 (August 16, 2019) ##

*   No changes.


## Rails 6.0.0.rc2 (July 22, 2019) ##

*   No changes.


## Rails 6.0.0.rc1 (April 24, 2019) ##

*   Don't raise when analyzing an image whose type is unsupported by ImageMagick.

    Fixes #36065.

    *Guilherme Mansur*

*   Permit generating variants of BMP images.

    *Younes Serraj*


## Rails 6.0.0.beta3 (March 11, 2019) ##

*   No changes.


## Rails 6.0.0.beta2 (February 25, 2019) ##

*   No changes.


## Rails 6.0.0.beta1 (January 18, 2019) ##

*   [Rename npm package](https://github.com/rails/rails/pull/34905) from
    [`activestorage`](https://www.npmjs.com/package/activestorage) to
    [`@rails/activestorage`](https://www.npmjs.com/package/@rails/activestorage).

    *Javan Makhmali*

*   Replace `config.active_storage.queue` with two options that indicate which
    queues analysis and purge jobs should use, respectively:

    * `config.active_storage.queues.analysis`
    * `config.active_storage.queues.purge`

    `config.active_storage.queue` is preferred over the new options when it's
    set, but it is deprecated and will be removed in Rails 6.1.

    *George Claghorn*

*   Permit generating variants of TIFF images.

    *Luciano Sousa*

*   Use base36 (all lowercase) for all new Blob keys to prevent
    collisions and undefined behavior with case-insensitive filesystems and
    database indices.

    *Julik Tarkhanov*

*   It doesn’t include an `X-CSRF-Token` header if a meta tag is not found on
    the page. It previously included one with a value of `undefined`.

    *Cameron Bothner*

*   Fix `ArgumentError` when uploading to amazon s3

    *Hiroki Sanpei*

*   Add progressive JPG to default list of variable content types

    *Maurice Kühlborn*

*   Add `ActiveStorage.routes_prefix` for configuring generated routes.

    *Chris Bisnett*

*   `ActiveStorage::Service::AzureStorageService` only handles specifically
    relevant types of `Azure::Core::Http::HTTPError`. It previously obscured
    other types of `HTTPError`, which is the azure-storage gem’s catch-all
    exception class.

    *Cameron Bothner*

*   `ActiveStorage::DiskController#show` generates a 404 Not Found response when
    the requested file is missing from the disk service. It previously raised
    `Errno::ENOENT`.

    *Cameron Bothner*

*   `ActiveStorage::Blob#download` and `ActiveStorage::Blob#open` raise
    `ActiveStorage::FileNotFoundError` when the corresponding file is missing
    from the storage service. Services translate service-specific missing object
    exceptions (e.g. `Google::Cloud::NotFoundError` for the GCS service and
    `Errno::ENOENT` for the disk service) into
    `ActiveStorage::FileNotFoundError`.

    *Cameron Bothner*

*   Added the `ActiveStorage::SetCurrent` concern for custom Active Storage
    controllers that can't inherit from `ActiveStorage::BaseController`.

    *George Claghorn*

*   Active Storage error classes like `ActiveStorage::IntegrityError` and
    `ActiveStorage::UnrepresentableError` now inherit from `ActiveStorage::Error`
    instead of `StandardError`. This permits rescuing `ActiveStorage::Error` to
    handle all Active Storage errors.

    *Andrei Makarov*, *George Claghorn*

*   Uploaded files assigned to a record are persisted to storage when the record
    is saved instead of immediately.

    In Rails 5.2, the following causes an uploaded file in `params[:avatar]` to
    be stored:

    ```ruby
    @user.avatar = params[:avatar]
    ```

    In Rails 6, the uploaded file is stored when `@user` is successfully saved.

    *George Claghorn*

*   Add the ability to reflect on defined attachments using the existing
    ActiveRecord reflection mechanism.

    *Kevin Deisz*

*   Variant arguments of `false` or `nil` will no longer be passed to the
    processor. For example, the following will not have the monochrome
    variation applied:

    ```ruby
      avatar.variant(monochrome: false)
    ```

    *Jacob Smith*

*   Generated attachment getter and setter methods are created
    within the model's `GeneratedAssociationMethods` module to
    allow overriding and composition using `super`.

    *Josh Susser*, *Jamon Douglas*

*   Add `ActiveStorage::Blob#open`, which downloads a blob to a tempfile on disk
    and yields the tempfile. Deprecate `ActiveStorage::Downloading`.

    *David Robertson*, *George Claghorn*

*   Pass in `identify: false` as an argument when providing a `content_type` for
    `ActiveStorage::Attached::{One,Many}#attach` to bypass automatic content
    type inference. For example:

    ```ruby
      @message.image.attach(
        io: File.open('/path/to/file'),
        filename: 'file.pdf',
        content_type: 'application/pdf',
        identify: false
      )
    ```

    *Ryan Davidson*

*   The Google Cloud Storage service properly supports streaming downloads.
    It now requires version 1.11 or newer of the google-cloud-storage gem.

    *George Claghorn*

*   Use the [ImageProcessing](https://github.com/janko-m/image_processing) gem
    for Active Storage variants, and deprecate the MiniMagick backend.

    This means that variants are now automatically oriented if the original
    image was rotated. Also, in addition to the existing ImageMagick
    operations, variants can now use `:resize_to_fit`, `:resize_to_fill`, and
    other ImageProcessing macros. These are now recommended over raw `:resize`,
    as they also sharpen the thumbnail after resizing.

    The ImageProcessing gem also comes with a backend implemented on
    [libvips](http://jcupitt.github.io/libvips/), an alternative to
    ImageMagick which has significantly better performance than
    ImageMagick in most cases, both in terms of speed and memory usage. In
    Active Storage it's now possible to switch to the libvips backend by
    changing `Rails.application.config.active_storage.variant_processor` to
    `:vips`.

    *Janko Marohnić*

*   Rails 6 requires Ruby 2.5.0 or newer.

    *Jeremy Daer*, *Kasper Timm Hansen*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/activestorage/CHANGELOG.md) for previous changes.
