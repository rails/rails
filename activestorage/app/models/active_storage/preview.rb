# frozen_string_literal: true

# Some non-image blobs can be previewed: that is, they can be presented as images. A video blob can be previewed by
# extracting its first frame, and a PDF blob can be previewed by extracting its first page.
#
# Active Storage provides previewers for videos and PDFs. You can add your own previewers or remove the built-in ones
# by modifying +ActiveStorage.previewers+.
#
#   ActiveStorage.previewers
#   # => [ ActiveStorage::Previewer::PdfPreviewer, ActiveStorage::Previewer::VideoPreviewer ]
#
#   ActiveStorage.previewers << CustomPreviewer
#
# The built-in previewers rely on third-party system libraries:
#
#   * {ffmpeg}(https://www.ffmpeg.org)
#   * {mupdf}(https://mupdf.com)
#
# These libraries are not provided by Rails; to use the built-in previewers, you must install them yourself.
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
