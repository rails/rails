# frozen_string_literal: true

gem "google-cloud-storage", "~> 1.8"

require "google/cloud/storage"
require "net/http"

require "active_support/core_ext/object/to_query"

module ActiveStorage
  # Wraps the Google Cloud Storage as an Active Storage service. See ActiveStorage::Service for the generic API
  # documentation that applies to all services.
  class Service::GCSService < Service
    def initialize(**config)
      @config = config
    end

    def upload(key, io, checksum: nil, content_type: nil, disposition: nil, filename: nil)
      instrument :upload, key: key, checksum: checksum do
        begin
          # GCS's signed URLs don't include params such as response-content-type response-content_disposition
          # in the signature, which means an attacker can modify them and bypass our effort to force these to
          # binary and attachment when the file's content type requires it. The only way to force them is to
          # store them as object's metadata.
          content_disposition = content_disposition_with(type: disposition, filename: filename) if disposition && filename
          bucket.create_file(io, key, md5: checksum, content_type: content_type, content_disposition: content_disposition)
        rescue Google::Cloud::InvalidArgumentError
          raise ActiveStorage::IntegrityError
        end
      end
    end

    def update_metadata(key, content_type:, disposition: nil, filename: nil)
      instrument :update_metadata, key: key, content_type: content_type, disposition: disposition do
        file_for(key).update do |file|
          file.content_type = content_type
          file.content_disposition = content_disposition_with(type: disposition, filename: filename) if disposition && filename
        end
      end
    end

    # FIXME: Download in chunks when given a block.
    def download(key)
      instrument :download, key: key do
        io = file_for(key).download
        io.rewind

        if block_given?
          yield io.string
        else
          io.string
        end
      end
    end

    def download_chunk(key, range)
      instrument :download_chunk, key: key, range: range do
        file = file_for(key)
        uri  = URI(file.signed_url(expires: 30.seconds))

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
        bucket.files(prefix: prefix).all do |file|
          begin
            file.delete
          rescue Google::Cloud::NotFoundError
            # Ignore concurrently-deleted files
          end
        end
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
