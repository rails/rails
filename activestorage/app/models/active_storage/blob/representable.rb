# frozen_string_literal: true

require "marcel"

module ActiveStorage::Blob::Representable
  extend ActiveSupport::Concern

  included do
    has_many :variant_records, class_name: "ActiveStorage::VariantRecord", dependent: false
    before_destroy { variant_records.destroy_all if ActiveStorage.track_variants }

    has_one_attached :preview_image
  end

  # Returns an ActiveStorage::Variant or ActiveStorage::VariantWithRecord instance with the set of +transformations+ provided.
  # This is only relevant for image files, and it allows any image to be transformed for size, colors, and the like. Example:
  #
  #   avatar.variant(resize_to_limit: [100, 100]).processed.url
  #
  # This will create and process a variant of the avatar blob that's constrained to a height and width of 100px.
  # Then it'll upload said variant to the service according to a derivative key of the blob and the transformations.
  #
  # Frequently, though, you don't actually want to transform the variant right away. But rather simply refer to a
  # specific variant that can be created by a controller on-demand. Like so:
  #
  #   <%= image_tag Current.user.avatar.variant(resize_to_limit: [100, 100]) %>
  #
  # This will create a URL for that specific blob with that specific variant, which the ActiveStorage::Representations::ProxyController
  # or ActiveStorage::Representations::RedirectController can then produce on-demand.
  #
  # Raises ActiveStorage::InvariableError if the variant processor cannot
  # transform the blob. To determine whether a blob is variable, call
  # ActiveStorage::Blob#variable?.
  #
  # ==== Options
  #
  # Options are defined by the {image_processing gem}[https://github.com/janko/image_processing],
  # and depend on which variant processor you are using:
  # {Vips}[https://github.com/janko/image_processing/blob/master/doc/vips.md] or
  # {MiniMagick}[https://github.com/janko/image_processing/blob/master/doc/minimagick.md].
  # However, both variant processors support the following options:
  #
  # [+:resize_to_limit+]
  #   Downsizes the image to fit within the specified dimensions while retaining
  #   the original aspect ratio. Will only resize the image if it's larger than
  #   the specified dimensions.
  #
  #       user.avatar.variant(resize_to_limit: [100, 100])
  #
  # [+:resize_to_fit+]
  #   Resizes the image to fit within the specified dimensions while retaining
  #   the original aspect ratio. Will downsize the image if it's larger than the
  #   specified dimensions or upsize if it's smaller.
  #
  #       user.avatar.variant(resize_to_fit: [100, 100])
  #
  # [+:resize_to_fill+]
  #   Resizes the image to fill the specified dimensions while retaining the
  #   original aspect ratio. If necessary, will crop the image in the larger
  #   dimension.
  #
  #       user.avatar.variant(resize_to_fill: [100, 100])
  #
  # [+:resize_and_pad+]
  #   Resizes the image to fit within the specified dimensions while retaining
  #   the original aspect ratio. If necessary, will pad the remaining area with
  #   transparent color if source image has alpha channel, black otherwise.
  #
  #       user.avatar.variant(resize_and_pad: [100, 100])
  #
  # [+:crop+]
  #   Extracts an area from an image. The first two arguments are the left and
  #   top edges of area to extract, while the last two arguments are the width
  #   and height of the area to extract.
  #
  #       user.avatar.variant(crop: [20, 50, 300, 300])
  #
  # [+:rotate+]
  #   Rotates the image by the specified angle.
  #
  #       user.avatar.variant(rotate: 90)
  #
  # Some options, including those listed above, can accept additional
  # processor-specific values which can be passed as a trailing hash:
  #
  #     <!-- Vips supports configuring `crop` for many of its transformations -->
  #     <%= image_tag user.avatar.variant(resize_to_fill: [100, 100, { crop: :centre }]) %>
  #
  # If migrating an existing application between MiniMagick and Vips, you will
  # need to update processor-specific options:
  #
  #     <!-- MiniMagick -->
  #     <%= image_tag user.avatar.variant(resize_to_limit: [100, 100], format: :jpeg,
  #           sampling_factor: "4:2:0", strip: true, interlace: "JPEG", colorspace: "sRGB", quality: 80) %>
  #
  #     <!-- Vips -->
  #     <%= image_tag user.avatar.variant(resize_to_limit: [100, 100], format: :jpeg,
  #           saver: { subsample_mode: "on", strip: true, interlace: true, quality: 80 }) %>
  #
  def variant(transformations)
    if variable?
      variant_class.new(self, ActiveStorage::Variation.wrap(transformations).default_to(default_variant_transformations))
    else
      raise ActiveStorage::InvariableError, "Can't transform blob with ID=#{id} and content_type=#{content_type}"
    end
  end

  # Returns true if the variant processor can transform the blob (its content
  # type is in +ActiveStorage.variable_content_types+).
  def variable?
    ActiveStorage.variable_content_types.include?(content_type)
  end


  # Returns an ActiveStorage::Preview instance with the set of +transformations+ provided. A preview is an image generated
  # from a non-image blob. Active Storage comes with built-in previewers for videos and PDF documents. The video previewer
  # extracts the first frame from a video and the PDF previewer extracts the first page from a PDF document.
  #
  #   blob.preview(resize_to_limit: [100, 100]).processed.url
  #
  # Avoid processing previews synchronously in views. Instead, link to a controller action that processes them on demand.
  # Active Storage provides one, but you may want to create your own (for example, if you need authentication). Here’s
  # how to use the built-in version:
  #
  #   <%= image_tag video.preview(resize_to_limit: [100, 100]) %>
  #
  # This method raises ActiveStorage::UnpreviewableError if no previewer accepts the receiving blob. To determine
  # whether a blob is accepted by any previewer, call ActiveStorage::Blob#previewable?.
  def preview(transformations)
    if previewable?
      ActiveStorage::Preview.new(self, transformations)
    else
      raise ActiveStorage::UnpreviewableError, "No previewer found for blob with ID=#{id} and content_type=#{content_type}"
    end
  end

  # Returns true if any registered previewer accepts the blob. By default, this will return true for videos and PDF documents.
  def previewable?
    ActiveStorage.previewers.any? { |klass| klass.accept?(self) }
  end


  # Returns an ActiveStorage::Preview for a previewable blob or an ActiveStorage::Variant for a variable image blob.
  #
  #   blob.representation(resize_to_limit: [100, 100]).processed.url
  #
  # Raises ActiveStorage::UnrepresentableError if the receiving blob is neither variable nor previewable. Call
  # ActiveStorage::Blob#representable? to determine whether a blob is representable.
  #
  # See ActiveStorage::Blob#preview and ActiveStorage::Blob#variant for more information.
  def representation(transformations)
    case
    when previewable?
      preview transformations
    when variable?
      variant transformations
    else
      raise ActiveStorage::UnrepresentableError, "No previewer found and can't transform blob with ID=#{id} and content_type=#{content_type}"
    end
  end

  # Returns true if the blob is variable or previewable.
  def representable?
    variable? || previewable?
  end

  def preview_image_needed_before_processing_variants? # :nodoc:
    previewable? && !preview_image.attached?
  end

  def create_preview_image_later(variations) # :nodoc:
    ActiveStorage::PreviewImageJob.perform_later(self, variations) if representable?
  end

  def preprocessed(transformations) # :nodoc:
    ActiveStorage::TransformJob.perform_later(self, transformations) if representable?
  end

  private
    def default_variant_transformations
      { format: default_variant_format }
    end

    def default_variant_format
      if web_image?
        format || :png
      else
        :png
      end
    end

    def format
      if filename.extension.present? && Marcel::MimeType.for(extension: filename.extension) == content_type
        filename.extension
      else
        Marcel::Magic.new(content_type.to_s).extensions.first
      end
    end

    def variant_class
      ActiveStorage.track_variants ? ActiveStorage::VariantWithRecord : ActiveStorage::Variant
    end
end
