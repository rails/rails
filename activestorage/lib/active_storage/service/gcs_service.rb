# frozen_string_literal: true

gem "google-cloud-storage", "~> 1.11"

require "google/cloud/storage"
require "net/http"

require "active_support/core_ext/object/to_query"
require "active_storage/filename"

module ActiveStorage
  # Wraps the Google Cloud Storage as an Active Storage service. See ActiveStorage::Service for the generic API
  # documentation that applies to all services.
  class Service::GCSService < Service
    def initialize(**config)
      @config = config
    end

    def upload(key, io, checksum: nil)
      instrument :upload, key: key, checksum: checksum do
        begin
          # The official GCS client library doesn't allow us to create a file with no Content-Type metadata.
          # We need the file we create to have no Content-Type so we can control it via the response-content-type
          # param in signed URLs. Workaround: let the GCS client create the file with an inferred
          # Content-Type (usually "application/octet-stream") then clear it.
          bucket.create_file(io, key, md5: checksum).update do |file|
            file.content_type = nil
          end
        rescue Google::Cloud::InvalidArgumentError
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
          file_for(key).download.string
        end
      end
    end

    def download_chunk(key, range)
      instrument :download_chunk, key: key, range: range do
        file_for(key).download(range: range).string
      end
    end

    def delete(key)
      instrument :delete, key: key do
        begin
          file_for(key).delete
        rescue Google::Cloud::NotFoundError
          # Ignore files already deleted
        end
      end
    end

    def delete_prefixed(prefix)
      instrument :delete_prefixed, prefix: prefix do
        bucket.files(prefix: prefix).all(&:delete)
      end
    end

    def exist?(key)
      instrument :exist, key: key do |payload|
        answer = file_for(key).exists?
        payload[:exist] = answer
        answer
      end
    end

    def url(key, expires_in:, filename:, content_type:, disposition:)
      instrument :url, key: key do |payload|
        generated_url = file_for(key).signed_url expires: expires_in, query: {
          "response-content-disposition" => content_disposition_with(type: disposition, filename: filename),
          "response-content-type" => content_type
        }

        payload[:url] = generated_url

        generated_url
      end
    end

    def url_for_direct_upload(key, expires_in:, checksum:, **)
      instrument :url, key: key do |payload|
        generated_url = bucket.signed_url key, method: "PUT", expires: expires_in, content_md5: checksum

        payload[:url] = generated_url

        generated_url
      end
    end

    def headers_for_direct_upload(key, checksum:, **)
      { "Content-MD5" => checksum }
    end

    private
      attr_reader :config

      def file_for(key, skip_lookup: true)
        bucket.file(key, skip_lookup: skip_lookup)
      end

      # Reads the file for the given key in chunks, yielding each to the block.
      def stream(key)
        file = file_for(key, skip_lookup: false)

        chunk_size = 5.megabytes
        offset = 0

        while offset < file.size
          yield file.download(range: offset..(offset + chunk_size - 1)).string
          offset += chunk_size
        end
      end

      def bucket
        @bucket ||= client.bucket(config.fetch(:bucket))
      end

      def client
        @client ||= Google::Cloud::Storage.new(config.except(:bucket))
      end
  end
end
