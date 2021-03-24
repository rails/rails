# frozen_string_literal: true

require "mime/types"

module ActiveStorage::Blob::Representable
  extend ActiveSupport::Concern

  included do
    has_many :variant_records, class_name: "ActiveStorage::VariantRecord", dependent: false
    before_destroy { variant_records.destroy_all if ActiveStorage.track_variants }

    has_one_attached :preview_image
  end

  # Returns an ActiveStorage::Variant instance with the set of +transformations+ provided. This is only relevant for image
  # files, and it allows any image to be transformed for size, colors, and the like. Example:
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
  # This will create a URL for that specific blob with that specific variant, which the ActiveStorage::RepresentationsController
  # can then produce on-demand.
  #
  # Raises ActiveStorage::InvariableError if ImageMagick cannot transform the blob. To determine whether a blob is
  # variable, call ActiveStorage::Blob#variable?.
  def variant(transformations)
    if variable?
      variant_class.new(self, ActiveStorage::Variation.wrap(transformations).default_to(default_variant_transformations))
    else
      raise ActiveStorage::InvariableError
    end
  end

  # Returns true if ImageMagick can transform the blob (its content type is in +ActiveStorage.variable_content_types+).
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
      raise ActiveStorage::UnpreviewableError
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
      raise ActiveStorage::UnrepresentableError
    end
  end

  # Returns true if the blob is variable or previewable.
  def representable?
    variable? || previewable?
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
      if filename.extension.present? && ::MIME::Types.type_for(filename.extension)&.to_s == content_type
        filename.extension
      else
        ::Mime::Types[content_type].first.extensions.first
      end
    end

    def variant_class
      ActiveStorage.track_variants ? ActiveStorage::VariantWithRecord : ActiveStorage::Variant
    end
end
