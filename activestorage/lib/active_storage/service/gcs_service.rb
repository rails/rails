# frozen_string_literal: true

gem "google-cloud-storage", "~> 1.8"

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

    # FIXME: Download in chunks when given a block.
    def download(key)
      instrument :download, key: key do
        io = file_for(key).download
        io.rewind

        if block_given?
          yield io.read
        else
          io.read
        end
      end
    end

    def download_chunk(key, range)
      instrument :download_chunk, key: key, range: range do
        uri = URI(url(key, expires_in: 30.seconds, filename: ActiveStorage::Filename.new(""), content_type: "application/octet-stream", disposition: "inline"))

        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |client|
          client.get(uri, "Range" => "bytes=#{range.begin}-#{range.exclude_end? ? range.end - 1 : range.end}").body
        end
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
      { "Content-Type" => "", "Content-MD5" => checksum }
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
