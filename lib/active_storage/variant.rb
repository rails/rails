require "active_storage/blob"
require "active_support/core_ext/object/inclusion"
require "mini_magick"

class ActiveStorage::Variant
  class_attribute :verifier

  ALLOWED_TRANSFORMATIONS = %i(
    resize rotate format flip fill monochrome orient quality roll scale sharpen shave shear size thumbnail
    transparent transpose transverse trim background bordercolor compress crop
  )

  attr_reader :blob, :variation
  delegate :service, to: :blob

  def self.find_or_process_by!(blob_key:, encoded_variant_key:)
    new(ActiveStorage::Blob.find_by!(key: blob_key), variation: verifier.verify(encoded_variant_key)).processed
  end

  def self.encode_key(variation)
    verifier.generate(variation)
  end

  def initialize(blob, variation:)
    @blob, @variation = blob, variation
  end

  def processed
    process unless processed?
    self
  end

  def url(expires_in: 5.minutes, disposition: :inline)
    service.url blob_variant_key, expires_in: expires_in, disposition: disposition, filename: blob.filename
  end

  def key
    verifier.generate(variation)
  end


  private
    def processed?
      service.exist?(blob_variant_key)
    end

    def process
      upload_variant transform(download_blob)
    end

    def download_blob
      service.download(blob.key)
    end

    def upload_variant(variant)
      service.upload blob_variant_key, variant
    end

    def blob_variant_key
      "variants/#{blob.key}/#{key}"
    end

    def transform(io)
      File.open \
        MiniMagick::Image.read(io).tap { |transforming_image|
          variation.each do |(method, argument)|
            if method = allowed_transformational_method(method.to_sym)
              if argument.blank? || argument == true
                transforming_image.public_send(method)
              else
                # FIXME: Consider whitelisting allowed arguments as well?
                transforming_image.public_send(method, argument)
              end
            end
          end
        }.path
    end

    def allowed_transformational_method(method)
      method.presence_in(ALLOWED_TRANSFORMATIONS)
    end
end
