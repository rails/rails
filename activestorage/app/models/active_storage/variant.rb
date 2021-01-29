# frozen_string_literal: true

# Image blobs can have variants that are the result of a set of transformations applied to the original.
# These variants are used to create thumbnails, fixed-size avatars, or any other derivative image from the
# original.
#
# Variants rely on {ImageProcessing}[https://github.com/janko-m/image_processing] gem for the actual transformations
# of the file, so you must add <tt>gem "image_processing"</tt> to your Gemfile if you wish to use variants. By
# default, images will be processed with {ImageMagick}[http://imagemagick.org] using the
# {MiniMagick}[https://github.com/minimagick/minimagick] gem, but you can also switch to the
# {libvips}[http://libvips.github.io/libvips/] processor operated by the {ruby-vips}[https://github.com/libvips/ruby-vips]
# gem).
#
#   Rails.application.config.active_storage.variant_processor
#   # => :mini_magick
#
#   Rails.application.config.active_storage.variant_processor = :vips
#   # => :vips
#
# Note that to create a variant it's necessary to download the entire blob file from the service. Because of this process,
# you also want to be considerate about when the variant is actually processed. You shouldn't be processing variants inline
# in a template, for example. Delay the processing to an on-demand controller, like the one provided in
# ActiveStorage::RepresentationsController.
#
# To refer to such a delayed on-demand variant, simply link to the variant through the resolved route provided
# by Active Storage like so:
#
#   <%= image_tag Current.user.avatar.variant(resize_to_limit: [100, 100]) %>
#
# This will create a URL for that specific blob with that specific variant, which the ActiveStorage::RepresentationsController
# can then produce on-demand.
#
# When you do want to actually produce the variant needed, call +processed+. This will check that the variant
# has already been processed and uploaded to the service, and, if so, just return that. Otherwise it will perform
# the transformations, upload the variant to the service, and return itself again. Example:
#
#   avatar.variant(resize_to_limit: [100, 100]).processed.url
#
# This will create and process a variant of the avatar blob that's constrained to a height and width of 100.
# Then it'll upload said variant to the service according to a derivative key of the blob and the transformations.
#
# You can combine any number of ImageMagick/libvips operations into a variant, as well as any macros provided by the
# ImageProcessing gem (such as +resize_to_limit+):
#
#   avatar.variant(resize_to_limit: [800, 800], monochrome: true, rotate: "-90")
#
# Visit the following links for a list of available ImageProcessing commands and ImageMagick/libvips operations:
#
# * {ImageProcessing::MiniMagick}[https://github.com/janko-m/image_processing/blob/master/doc/minimagick.md#methods]
# * {ImageMagick reference}[https://www.imagemagick.org/script/mogrify.php]
# * {ImageProcessing::Vips}[https://github.com/janko-m/image_processing/blob/master/doc/vips.md#methods]
# * {ruby-vips reference}[http://www.rubydoc.info/gems/ruby-vips/Vips/Image]
class ActiveStorage::Variant
  attr_reader :blob, :variation
  delegate :service, to: :blob
  delegate :content_type, to: :variation

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

  # Returns the URL of the blob variant on the service. See {ActiveStorage::Blob#url} for details.
  #
  # Use <tt>url_for(variant)</tt> (or the implied form, like +link_to variant+ or +redirect_to variant+) to get the stable URL
  # for a variant that points to the ActiveStorage::RepresentationsController, which in turn will use this +service_call+ method
  # for its redirection.
  def url(expires_in: ActiveStorage.service_urls_expire_in, disposition: :inline)
    service.url key, expires_in: expires_in, disposition: disposition, filename: filename, content_type: content_type
  end

  alias_method :service_url, :url
  deprecate service_url: :url

  # Downloads the file associated with this variant. If no block is given, the entire file is read into memory and returned.
  # That'll use a lot of RAM for very large files. If a block is given, then the download is streamed and yielded in chunks.
  def download(&block)
    service.download key, &block
  end

  def filename
    ActiveStorage::Filename.new "#{blob.filename.base}.#{variation.format}"
  end

  alias_method :content_type_for_serving, :content_type

  def forced_disposition_for_serving #:nodoc:
    nil
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
      blob.open do |input|
        variation.transform(input) do |output|
          service.upload(key, output, content_type: content_type)
        end
      end
    end
end
