require "aws-sdk"

class ActiveFile::Sites::S3Site < ActiveFile::Site
  attr_reader :client, :bucket

  def initialize(access_key_id:, secret_access_key:, region:, bucket:)
    @client = Aws::S3::Resource.new(access_key_id: access_key_id, secret_access_key: secret_access_key, region: region)
    @bucket = @client.bucket(bucket)
  end

  def upload(key, data)
    object_for(key).put(body: data)
  end

  def download(key)
    if block_given?
      stream(key, &block)
    else
      object_for(key).get.body.read
    end
  end

  def delete(key)
    object_for(key).delete
  end

  def exist?(key)
    object_for(key).exists?
  end


  def url(key, disposition: :inline, expires_in: nil)
    object_for(key).presigned_url(:get, expires_in: expires_in)
  end

  def byte_size(key)
    object_for(key).size
  end

  def checksum(key)
    object_for(key).etag.remove(/"/)
  end


  private
    def object_for(key)
      bucket.object(key)
    end

    # Reads the object for the given key in chunks, yielding each to the block.
    def stream(key, options = {}, &block)
      object = object_for(key)

      chunk_size = 5242880 # 5 megabytes
      offset = 0

      while offset < object.content_length
        yield object.read(options.merge(:range => "bytes=#{offset}-#{offset + chunk_size - 1}"))
        offset += chunk_size
      end
    end
end
