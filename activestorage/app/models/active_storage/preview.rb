# frozen_string_literal: true

# Some non-image blobs can be previewed: that is, they can be presented as images. A video blob can be previewed by
# extracting its first frame, and a PDF blob can be previewed by extracting its first page.
#
# A previewer extracts a preview image from a blob. Active Storage provides previewers for videos and PDFs:
# ActiveStorage::Previewer::VideoPreviewer and ActiveStorage::Previewer::PDFPreviewer. Build custom previewers by
# subclassing ActiveStorage::Previewer and implementing the requisite methods. Consult the ActiveStorage::Previewer
# documentation for more details on what's required of previewers.
#
# To choose the previewer for a blob, Active Storage calls +accept?+ on each registered previewer in order. It uses the
# first previewer for which +accept?+ returns true when given the blob. In a Rails application, add or remove previewers
# by manipulating +Rails.application.config.active_storage.previewers+ in an initializer:
#
#   Rails.application.config.active_storage.previewers
#   # => [ ActiveStorage::Previewer::PDFPreviewer, ActiveStorage::Previewer::VideoPreviewer ]
#
#   # Add a custom previewer for Microsoft Office documents:
#   Rails.application.config.active_storage.previewers << DOCXPreviewer
#   # => [ ActiveStorage::Previewer::PDFPreviewer, ActiveStorage::Previewer::VideoPreviewer, DOCXPreviewer ]
#
# Outside of a Rails application, modify +ActiveStorage.previewers+ instead.
#
# The built-in previewers rely on third-party system libraries:
#
#   * {ffmpeg}[https://www.ffmpeg.org]
#   * {mupdf}[https://mupdf.com]
#
# These libraries are not provided by Rails. You must install them yourself to use the built-in previewers. Before you
# install and use third-party software, make sure you understand the licensing implications of doing so.
class ActiveStorage::Preview
  class UnprocessedError < StandardError; end

  attr_reader :blob, :variation

  def initialize(blob, variation_or_variation_key)
    @blob, @variation = blob, ActiveStorage::Variation.wrap(variation_or_variation_key)
  end

  def processed
    process unless processed?
    self
  end

  def image
    blob.preview_image
  end

  def service_url(**options)
    if processed?
      variant.service_url(options)
    else
      raise UnprocessedError
    end
  end

  private
    def processed?
      image.attached?
    end

    def process
      previewer.preview { |attachable| image.attach(attachable) }
    end

    def variant
      ActiveStorage::Variant.new(image, variation).processed
    end


    def previewer
      previewer_class.new(blob)
    end

    def previewer_class
      ActiveStorage.previewers.detect { |klass| klass.accept?(blob) }
    end
end
