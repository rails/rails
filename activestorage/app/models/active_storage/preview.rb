# frozen_string_literal: true

# = Active Storage \Preview
#
# Some non-image blobs can be previewed: that is, they can be presented as images. A video blob can be previewed by
# extracting its first frame, and a PDF blob can be previewed by extracting its first page.
#
# A previewer extracts a preview image from a blob. Active Storage provides previewers for videos and PDFs.
# ActiveStorage::Previewer::VideoPreviewer is used for videos whereas ActiveStorage::Previewer::PopplerPDFPreviewer
# and ActiveStorage::Previewer::MuPDFPreviewer are used for PDFs. Build custom previewers by
# subclassing ActiveStorage::Previewer and implementing the requisite methods. Consult the ActiveStorage::Previewer
# documentation for more details on what's required of previewers.
#
# To choose the previewer for a blob, Active Storage calls +accept?+ on each registered previewer in order. It uses the
# first previewer for which +accept?+ returns true when given the blob. In a \Rails application, add or remove previewers
# by manipulating +Rails.application.config.active_storage.previewers+ in an initializer:
#
#   Rails.application.config.active_storage.previewers
#   # => [ ActiveStorage::Previewer::PopplerPDFPreviewer, ActiveStorage::Previewer::MuPDFPreviewer, ActiveStorage::Previewer::VideoPreviewer ]
#
#   # Add a custom previewer for Microsoft Office documents:
#   Rails.application.config.active_storage.previewers << DOCXPreviewer
#   # => [ ActiveStorage::Previewer::PopplerPDFPreviewer, ActiveStorage::Previewer::MuPDFPreviewer, ActiveStorage::Previewer::VideoPreviewer, DOCXPreviewer ]
#
# Outside of a \Rails application, modify +ActiveStorage.previewers+ instead.
#
# The built-in previewers rely on third-party system libraries. Specifically, the built-in video previewer requires
# {FFmpeg}[https://www.ffmpeg.org]. Two PDF previewers are provided: one requires {Poppler}[https://poppler.freedesktop.org],
# and the other requires {muPDF}[https://mupdf.com] (version 1.8 or newer). To preview PDFs, install either Poppler or muPDF.
#
# These libraries are not provided by \Rails. You must install them yourself to use the built-in previewers. Before you
# install and use third-party software, make sure you understand the licensing implications of doing so.
class ActiveStorage::Preview
  include ActiveStorage::Blob::Servable

  class UnprocessedError < StandardError; end

  delegate :filename, :content_type, to: :variant

  attr_reader :blob, :variation

  def initialize(blob, variation_or_variation_key)
    @blob, @variation = blob, ActiveStorage::Variation.wrap(variation_or_variation_key)
  end

  # Processes the preview if it has not been processed yet. Returns the receiving +ActiveStorage::Preview+ instance for convenience:
  #
  #   blob.preview(resize_to_limit: [100, 100]).processed.url
  #
  # Processing a preview generates an image from its blob and attaches the preview image to the blob. Because the preview
  # image is stored with the blob, it is only generated once.
  def processed
    process unless processed?
    variant.processed
    self
  end

  # Returns the blob's attached preview image.
  def image
    blob.preview_image
  end

  # Returns the URL of the preview's variant on the service. Raises ActiveStorage::Preview::UnprocessedError if the
  # preview has not been processed yet.
  #
  # This method synchronously processes a variant of the preview image, so do not call it in views. Instead, generate
  # a stable URL that redirects to the URL returned by this method.
  def url(**options)
    if processed?
      variant.url(**options)
    else
      raise UnprocessedError
    end
  end

  # Returns a combination key of the blob and the variation that together identifies a specific variant.
  def key
    if processed?
      variant.key
    else
      raise UnprocessedError
    end
  end

  # Downloads the file associated with this preview's variant. If no block is
  # given, the entire file is read into memory and returned. That'll use a lot
  # of RAM for very large files. If a block is given, then the download is
  # streamed and yielded in chunks. Raises ActiveStorage::Preview::UnprocessedError
  # if the preview has not been processed yet.
  def download(&block)
    if processed?
      variant.download(&block)
    else
      raise UnprocessedError
    end
  end

  private
    def processed?
      image.attached?
    end

    def process
      previewer.preview(service_name: blob.service_name) do |attachable|
        ActiveRecord::Base.connected_to(role: ActiveRecord.writing_role) do
          image.attach(attachable)
        end
      end
    end

    def variant
      image.variant(variation).processed
    end


    def previewer
      previewer_class.new(blob)
    end

    def previewer_class
      ActiveStorage.previewers.detect { |klass| klass.accept?(blob) }
    end
end
