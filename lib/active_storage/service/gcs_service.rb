require "google/cloud/storage"
require "active_support/core_ext/object/to_query"

class ActiveStorage::Service::GCSService < ActiveStorage::Service
  attr_reader :client, :bucket

  def initialize(project:, keyfile:, bucket:)
    @client = Google::Cloud::Storage.new(project: project, keyfile: keyfile)
    @bucket = @client.bucket(bucket)
  end

  def upload(key, io, checksum: nil)
    begin
      bucket.create_file(io, key, md5: checksum)
    rescue Google::Cloud::InvalidArgumentError
      raise ActiveStorage::IntegrityError
    end
  end

  # FIXME: Add streaming when given a block
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

  def url(key, expires_in:, disposition:, filename:)
    file_for(key).signed_url(expires: expires_in) + "&" +
      { "response-content-disposition" => "#{disposition}; filename=\"#{filename}\"" }.to_query
  end

  private
    def file_for(key)
      bucket.file(key)
    end
end
