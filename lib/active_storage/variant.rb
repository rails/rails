require "active_storage/blob"
require "mini_magick"

class ActiveStorage::Variant
  class_attribute :verifier

  attr_reader :blob, :variation
  delegate :service, to: :blob

  def self.lookup(blob_key:, variation_key:)
    new ActiveStorage::Blob.find_by!(key: blob_key), variation: verifier.verify(variation_key)
  end

  def self.encode_key(variation)
    verifier.generate(variation)
  end

  def initialize(blob, variation:)
    @blob, @variation = blob, variation
  end

  def url(expires_in: 5.minutes, disposition: :inline)
    perform unless exist?
    service.url key, expires_in: expires_in, disposition: disposition, filename: blob.filename
  end

  def key
    verifier.generate(variation)
  end

  private
    def perform
      upload_variant transform(download_blob)
    end

    def download_blob
      service.download(blob.key)
    end

    def upload_variant(variation)
      service.upload key, variation
    end

    def transform(io)
      # FIXME: Actually do a variant based on the variation
      File.open MiniMagick::Image.read(io).resize("500x500").path
    end

    def exist?
      service.exist?(key)
    end
end
