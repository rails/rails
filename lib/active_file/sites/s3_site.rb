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
      object_for(key).read
    end
  end

  def delete(key)
    object_for(key).delete
  end

  def exists?(key)
    object_for(key).exists?
  end


  def byte_size(key)
    object_for(key).head[:size]
  end

  def checksum(key)
    head = object_for(key).head

    # If the etag has no dashes, it's the MD5
    if !head.etag.include?("-")
      head.etag.gsub('"', '')
    # Check for md5 in metadata if it was uploaded via multipart
    elsif md5sum = head.meta["md5sum"]
      md5sum
    # Otherwise, we don't have a digest yet for this key
    else
      nil
    end
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
