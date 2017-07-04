require "google/cloud/storage"

class ActiveFile::Sites::GCSSite < ActiveFile::Site
  attr_reader :client, :bucket

  def initialize(project:, keyfile:, bucket:)
    @client = Google::Cloud::Storage.new(project: project, keyfile: keyfile)
    @bucket = @client.bucket(bucket)
  end

  def upload(key, data)
    bucket.create_file(data, key)
  end

  def download(key)
    io = file_for(key).download
    io.rewind
    io.read
  end

  def delete(key)
    file_for(key).try(:delete)
  end

  def exist?(key)
    file_for(key).present?
  end


  def byte_size(key)
    file_for(key).size
  end

  def checksum(key)
    convert_to_hex base64: file_for(key).md5
  end


  private
    def file_for(key)
      bucket.file(key)
    end

    def convert_to_hex(base64:)
      base64.unpack("m0").first.unpack("H*").first
    end
end
