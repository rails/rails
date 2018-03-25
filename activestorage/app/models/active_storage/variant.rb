# frozen_string_literal: true

require "active_storage/downloading"

# Image blobs can have variants that are the result of a set of transformations applied to the original.
# These variants are used to create thumbnails, fixed-size avatars, or any other derivative image from the
# original.
#
# Variants rely on {MiniMagick}[https://github.com/minimagick/minimagick] for the actual transformations
# of the file, so you must add <tt>gem "mini_magick"</tt> to your Gemfile if you wish to use variants.
#
# Note that to create a variant it's necessary to download the entire blob file from the service and load it
# into memory. The larger the image, the more memory is used. Because of this process, you also want to be
# considerate about when the variant is actually processed. You shouldn't be processing variants inline in a
# template, for example. Delay the processing to an on-demand controller, like the one provided in
# ActiveStorage::VariantsController.
#
# To refer to such a delayed on-demand variant, simply link to the variant through the resolved route provided
# by Active Storage like so:
#
#   <%= image_tag Current.user.avatar.variant(resize: "100x100") %>
#
# This will create a URL for that specific blob with that specific variant, which the ActiveStorage::VariantsController
# can then produce on-demand.
#
# When you do want to actually produce the variant needed, call +processed+. This will check that the variant
# has already been processed and uploaded to the service, and, if so, just return that. Otherwise it will perform
# the transformations, upload the variant to the service, and return itself again. Example:
#
#   avatar.variant(resize: "100x100").processed.service_url
#
# This will create and process a variant of the avatar blob that's constrained to a height and width of 100.
# Then it'll upload said variant to the service according to a derivative key of the blob and the transformations.
#
# A list of all possible transformations is available at https://www.imagemagick.org/script/mogrify.php. You can
# combine as many as you like freely:
#
#   avatar.variant(resize: "100x100", monochrome: true, flip: "-90")
class ActiveStorage::Variant
  include ActiveStorage::Downloading

  WEB_IMAGE_CONTENT_TYPES = %w( image/png image/jpeg image/jpg image/gif )

  attr_reader :blob, :variation
  delegate :service, to: :blob

  def initialize(blob, variation_or_variation_key)
    @blob, @variation = blob, ActiveStorage::Variation.wrap(variation_or_variation_key)
  end

  # Returns the variant instance itself after it's been processed or an existing processing has been found on the service.
  def processed
    process unless processed?
    self
  end

  # Returns a combination key of the blob and the variation that together identifies a specific variant.
  def key
    "variants/#{blob.key}/#{Digest::SHA256.hexdigest(variation.key)}"
  end

  # Returns the URL of the variant on the service. This URL is intended to be short-lived for security and not used directly
  # with users. Instead, the +service_url+ should only be exposed as a redirect from a stable, possibly authenticated URL.
  # Hiding the +service_url+ behind a redirect also gives you the power to change services without updating all URLs. And
  # it allows permanent URLs that redirect to the +service_url+ to be cached in the view.
  #
  # Use <tt>url_for(variant)</tt> (or the implied form, like +link_to variant+ or +redirect_to variant+) to get the stable URL
  # for a variant that points to the ActiveStorage::VariantsController, which in turn will use this +service_call+ method
  # for its redirection.
  def service_url(expires_in: service.url_expires_in, disposition: :inline, **options)
    service.url key, expires_in: expires_in, disposition: disposition, filename: filename, content_type: content_type, **options
  end

  # Returns the receiving variant. Allows ActiveStorage::Variant and ActiveStorage::Preview instances to be used interchangeably.
  def image
    self
  end

  private
    def processed?
      service.exist?(key)
    end

    def process
      open_image do |image|
        transform image
        format image
        upload image
      end
    end


    def filename
      if WEB_IMAGE_CONTENT_TYPES.include?(blob.content_type)
        blob.filename
      else
        ActiveStorage::Filename.new("#{blob.filename.base}.png")
      end
    end

    def content_type
      blob.content_type.presence_in(WEB_IMAGE_CONTENT_TYPES) || "image/png"
    end


    def open_image(&block)
      image = download_image

      begin
        yield image
      ensure
        image.destroy!
      end
    end

    def download_image
      require "mini_magick"
      MiniMagick::Image.create(blob.filename.extension_with_delimiter) { |file| download_blob_to(file) }
    end

    def transform(image)
      variation.transform(image)
    end

    def format(image)
      image.format("PNG") unless WEB_IMAGE_CONTENT_TYPES.include?(blob.content_type)
    end

    def upload(image)
      File.open(image.path, "r") { |file| service.upload(key, file) }
    end
end
