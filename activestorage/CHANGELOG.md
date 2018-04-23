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
