require "aws-sdk"
require "active_support/core_ext/numeric/bytes"

class ActiveStorage::Service::S3Service < ActiveStorage::Service
  attr_reader :client, :bucket

  def initialize(access_key_id:, secret_access_key:, region:, bucket:)
    @client = Aws::S3::Resource.new(access_key_id: access_key_id, secret_access_key: secret_access_key, region: region)
    @bucket = @client.bucket(bucket)
  end

  def upload(key, io, checksum: nil)
    object_for(key).put(body: io, content_md5: checksum)
  rescue Aws::S3::Errors::BadDigest
    raise ActiveStorage::IntegrityError
  end

  def download(key)
    if block_given?
      stream(key, &block)
    else
      object_for(key).get.body.read.force_encoding(Encoding::BINARY)
    end
  end

  def delete(key)
    object_for(key).delete
  end

  def exist?(key)
    object_for(key).exists?
  end

  def url(key, expires_in:, disposition:, filename:)
    object_for(key).presigned_url :get, expires_in: expires_in,
      response_content_disposition: "#{disposition}; filename=\"#{filename}\""
  end

  private
    def object_for(key)
      bucket.object(key)
    end

    # Reads the object for the given key in chunks, yielding each to the block.
    def stream(key, options = {}, &block)
      object = object_for(key)

      chunk_size = 5.megabytes
      offset = 0

      while offset < object.content_length
        yield object.read(options.merge(range: "bytes=#{offset}-#{offset + chunk_size - 1}"))
        offset += chunk_size
      end
    end
end
