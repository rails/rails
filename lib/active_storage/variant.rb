require "active_storage/blob"
require "mini_magick"

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
      File.open MiniMagick::Image.read(io).tap { |image| variation.transform(image) }.path
    end
end
