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

*   Rails 6 requires Ruby 2.4.1 or newer.

    *Jeremy Daer*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/activestorage/CHANGELOG.md) for previous changes.
