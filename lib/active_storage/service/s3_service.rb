require "aws-sdk"
require "active_support/core_ext/numeric/bytes"

class ActiveStorage::Service::S3Service < ActiveStorage::Service
  attr_reader :client, :bucket

  def initialize(bucket:, client: nil, **client_options)
    @bucket = bucket
    @client = client || Aws::S3::Client.new(client_options)
  end

  def upload(key, io, checksum: nil)
    instrument :upload, key, checksum: checksum do
      begin
        client.put_object bucket: bucket, key: key, body: io, content_md5: checksum
      rescue Aws::S3::Errors::BadDigest
        raise ActiveStorage::IntegrityError
      end
    end
  end

  def download(key, &block)
    if block_given?
      instrument :streaming_download, key do
        client.get_object bucket: bucket, key: key, &block
      end
    else
      instrument :download, key do
        "".b.tap do |data|
          client.get_object bucket: bucket, key: key, response_target: data
        end
      end
    end
  end

  def delete(key)
    instrument :delete, key do
      client.delete_object bucket: bucket, key: key
    end
  end

  def exist?(key)
    instrument :exist, key do |payload|
      payload[:exist] =
        begin
          client.head_object bucket: bucket, key: key
        rescue Aws::S3::Errors::NoSuckKey
          false
        else
          true
        end
    end
  end

  def url(key, expires_in:, disposition:, filename:)
    instrument :url, key do |payload|
      payload[:url] = presigner.presigned_url :get_object,
        bucket: bucket, key: key, expires_in: expires_in,
        response_content_disposition: "#{disposition}; filename=\"#{filename}\""
    end
  end

  def url_for_direct_upload(key, expires_in:, content_type:, content_length:)
    instrument :url, key do |payload|
      payload[:url] = presigner.presigned_url :put_object,
        bucket: bucket, key: key, expires_in: expires_in,
        content_type: content_type, content_length: content_length
    end
  end

  private
    def presigner
      @presigner ||= Aws::S3::Presigner.new client: client
    end
end
