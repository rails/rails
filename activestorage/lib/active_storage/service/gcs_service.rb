require "google/cloud/storage"
require "active_support/core_ext/object/to_query"

# Wraps the Google Cloud Storage as a Active Storage service. See `ActiveStorage::Service` for the generic API
# documentation that applies to all services.
class ActiveStorage::Service::GCSService < ActiveStorage::Service
  attr_reader :client, :bucket

  def initialize(project:, keyfile:, bucket:)
    @client = Google::Cloud::Storage.new(project: project, keyfile: keyfile)
    @bucket = @client.bucket(bucket)
  end

  def upload(key, io, checksum: nil)
    instrument :upload, key, checksum: checksum do
      begin
        bucket.create_file(io, key, md5: checksum)
      rescue Google::Cloud::InvalidArgumentError
        raise ActiveStorage::IntegrityError
      end
    end
  end

  # FIXME: Add streaming when given a block
  def download(key)
    instrument :download, key do
      io = file_for(key).download
      io.rewind
      io.read
    end
  end

  def delete(key)
    instrument :delete, key do
      file_for(key).try(:delete)
    end
  end

  def exist?(key)
    instrument :exist, key do |payload|
      answer = file_for(key).present?
      payload[:exist] = answer
      answer
    end
  end

  def url(key, expires_in:, disposition:, filename:, content_type:)
    instrument :url, key do |payload|
      generated_url = file_for(key).signed_url expires: expires_in, query: {
        "response-content-disposition" => "#{disposition}; filename=\"#{filename}\"",
        "response-content-type" => content_type
      }

      payload[:url] = generated_url

      generated_url
    end
  end

  def url_for_direct_upload(key, expires_in:, content_type:, content_length:, checksum:)
    instrument :url, key do |payload|
      generated_url = bucket.signed_url key, method: "PUT", expires: expires_in,
        content_type: content_type, content_md5: checksum

      payload[:url] = generated_url

      generated_url
    end
  end

  def headers_for_direct_upload(key, content_type:, checksum:, **)
    { "Content-Type" => content_type, "Content-MD5" => checksum }
  end

  private
    def file_for(key)
      bucket.file(key)
    end
end
