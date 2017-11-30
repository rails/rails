# frozen_string_literal: true

gem "google-cloud-storage", "~> 1.8"

require "google/cloud/storage"
require "active_support/core_ext/object/to_query"

module ActiveStorage
  # Wraps the Google Cloud Storage as an Active Storage service. See ActiveStorage::Service for the generic API
  # documentation that applies to all services.
  class Service::GCSService < Service
    def initialize(**config)
      @config = config
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

    # FIXME: Download in chunks when given a block.
    def download(key)
      instrument :download, key do
        io = file_for(key).download
        io.rewind

        if block_given?
          yield io.read
        else
          io.read
        end
      end
    end

    def delete(key)
      instrument :delete, key do
        begin
          file_for(key).delete
        rescue Google::Cloud::NotFoundError
          # Ignore files already deleted
        end
      end
    end

    def exist?(key)
      instrument :exist, key do |payload|
        answer = file_for(key).exists?
        payload[:exist] = answer
        answer
      end
    end

    def url(key, expires_in:, filename:, content_type:, disposition:)
      instrument :url, key do |payload|
        generated_url = file_for(key).signed_url expires: expires_in, query: {
          "response-content-disposition" => content_disposition_with(type: disposition, filename: filename),
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
      attr_reader :config

      def file_for(key)
        bucket.file(key, skip_lookup: true)
      end

      def bucket
        @bucket ||= client.bucket(config.fetch(:bucket))
      end

      def client
        @client ||= Google::Cloud::Storage.new(config.except(:bucket))
      end
  end
end
