require "active_storage/blob"

# Image blobs can have variants that are the result of a set of transformations applied to the original.
class ActiveStorage::Variant
  attr_reader :blob, :variation
  delegate :service, to: :blob

  def initialize(blob, variation)
    @blob, @variation = blob, variation
  end

  def processed
    process unless service.exist?(key)
    self
  end

  def key
    "variants/#{blob.key}/#{variation.key}"
  end

  def url(expires_in: 5.minutes, disposition: :inline)
    service.url key, expires_in: expires_in, disposition: disposition, filename: blob.filename
  end


  private
    def process
      service.upload key, transform(service.download(blob.key))
    end

    def transform(io)
      require "mini_magick"
      File.open MiniMagick::Image.read(io).tap { |image| variation.transform(image) }.path
    end
end
