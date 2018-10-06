# frozen_string_literal: true

require "aws-sdk-s3"
require "active_support/core_ext/numeric/bytes"

module ActiveStorage
  # Wraps the Amazon Simple Storage Service (S3) as an Active Storage service.
  # See ActiveStorage::Service for the generic API documentation that applies to all services.
  class Service::S3Service < Service
    attr_reader :client, :bucket, :upload_options

    def initialize(bucket:, upload: {}, **options)
      @client = Aws::S3::Resource.new(**options)
      @bucket = @client.bucket(bucket)

      @upload_options = upload
    end

    def upload(key, io, checksum: nil)
      instrument :upload, key: key, checksum: checksum do
        begin
          object_for(key).put(upload_options.merge(body: io, content_md5: checksum))
        rescue Aws::S3::Errors::BadDigest
          raise ActiveStorage::IntegrityError
        end
      end
    end

    def download(key, &block)
      if block_given?
        instrument :streaming_download, key: key do
          stream(key, &block)
        end
      else
        instrument :download, key: key do
          begin
            object_for(key).get.body.string.force_encoding(Encoding::BINARY)
          rescue Aws::S3::Errors::NoSuchKey
            raise ActiveStorage::FileNotFoundError
          end
        end
      end
    end

    def download_chunk(key, range)
      instrument :download_chunk, key: key, range: range do
        begin
          object_for(key).get(range: "bytes=#{range.begin}-#{range.exclude_end? ? range.end - 1 : range.end}").body.read.force_encoding(Encoding::BINARY)
        rescue Aws::S3::Errors::NoSuchKey
          raise ActiveStorage::FileNotFoundError
        end
      end
    end

    def delete(key)
      instrument :delete, key: key do
        object_for(key).delete
      end
    end

    def delete_prefixed(prefix)
      instrument :delete_prefixed, prefix: prefix do
        bucket.objects(prefix: prefix).batch_delete!
      end
    end

    def exist?(key)
      instrument :exist, key: key do |payload|
        answer = object_for(key).exists?
        payload[:exist] = answer
        answer
      end
    end

    def url(key, expires_in:, filename:, disposition:, content_type:)
      instrument :url, key: key do |payload|
        generated_url = object_for(key).presigned_url :get, expires_in: expires_in.to_i,
          response_content_disposition: content_disposition_with(type: disposition, filename: filename),
          response_content_type: content_type

        payload[:url] = generated_url

        generated_url
      end
    end

    def url_for_direct_upload(key, expires_in:, content_type:, content_length:, checksum:)
      instrument :url, key: key do |payload|
        generated_url = object_for(key).presigned_url :put, expires_in: expires_in.to_i,
          content_type: content_type, content_length: content_length, content_md5: checksum

        payload[:url] = generated_url

        generated_url
      end
    end

    def headers_for_direct_upload(key, content_type:, checksum:, **)
      { "Content-Type" => content_type, "Content-MD5" => checksum }
    end

    private
      def object_for(key)
        bucket.object(key)
      end

      # Reads the object for the given key in chunks, yielding each to the block.
      def stream(key)
        object = object_for(key)

        chunk_size = 5.megabytes
        offset = 0

        raise ActiveStorage::FileNotFoundError unless object.exists?

        while offset < object.content_length
          yield object.get(range: "bytes=#{offset}-#{offset + chunk_size - 1}").body.read.force_encoding(Encoding::BINARY)
          offset += chunk_size
        end
      end
  end
end
