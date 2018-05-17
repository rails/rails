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
