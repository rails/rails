# frozen_string_literal: true

gem "azure-blob-storage"

require "active_support/core_ext/numeric/bytes"
require "azure_blob_storage"

module ActiveStorage
  # = Active Storage \Azure Storage \Service
  #
  # Wraps the Microsoft Azure Storage Blob Service as an Active Storage service.
  # See ActiveStorage::Service for the generic API documentation that applies to all services.
  class Service::AzureStorageService < Service
    attr_reader :client, :container, :signer

    def initialize(storage_account_name:, storage_access_key:, container:, public: false, **options)
      @container = container
      @public = public
      @client = AzureBlobStorage::Client.new(
        account_name: storage_account_name,
        access_key: storage_access_key,
        container: container,
        **options)
    end

    def upload(key, io, checksum: nil, filename: nil, content_type: nil, disposition: nil, custom_metadata: {}, **)
      instrument :upload, key: key, checksum: checksum do
        handle_errors do
          content_disposition = content_disposition_with(filename: filename, type: disposition) if disposition && filename

          client.create_block_blob(key, IO.try_convert(io) || io, content_md5: checksum, content_type: content_type, content_disposition: content_disposition, metadata: custom_metadata)
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
          handle_errors do
            io = client.get_blob(key)
            io.force_encoding(Encoding::BINARY)
          end
        end
      end
    end

    def download_chunk(key, range)
      instrument :download_chunk, key: key, range: range do
        handle_errors do
          io = client.get_blob(key, start: range.begin, end: range.exclude_end? ? range.end - 1 : range.end)
          io.force_encoding(Encoding::BINARY)
        end
      end
    end

    def delete(key)
      instrument :delete, key: key do
        client.delete_blob(key)
      rescue AzureBlobStorage::Http::FileNotFoundError
        # Ignore files already deleted
      end
    end

    def delete_prefixed(prefix)
      instrument :delete_prefixed, prefix: prefix do
        client.delete_prefix(prefix)
      end
    end

    def exist?(key)
      instrument :exist, key: key do |payload|
        payload[:exist] = blob_for(key).present?
      end
    end

    def url_for_direct_upload(key, expires_in:, content_type:, content_length:, checksum:, custom_metadata: {})
      instrument :url, key: key do |payload|
        generated_url = client.signed_uri(
          key,
          permissions: "rw",
          expiry: format_expiry(expires_in)
        ).to_s

        payload[:url] = generated_url

        generated_url
      end
    end

    def headers_for_direct_upload(key, content_type:, checksum:, filename: nil, disposition: nil, custom_metadata: {}, **)
      content_disposition = content_disposition_with(type: disposition, filename: filename) if filename

      { "Content-Type" => content_type, "Content-MD5" => checksum, "x-ms-blob-content-disposition" => content_disposition, "x-ms-blob-type" => "BlockBlob", **custom_metadata_headers(custom_metadata) }
    end

    def compose(source_keys, destination_key, filename: nil, content_type: nil, disposition: nil, custom_metadata: {})
      content_disposition = content_disposition_with(type: disposition, filename: filename) if disposition && filename

      client.create_append_blob(
        destination_key,
        content_type: content_type,
        content_disposition: content_disposition,
        metadata: custom_metadata,
      )

      source_keys.each do |source_key|
        stream(source_key) do |chunk|
          client.append_blob_block(destination_key, chunk)
        end
      end
    end

    private
      def private_url(key, expires_in:, filename:, disposition:, content_type:, **)
        client.signed_uri(
          key,
          permissions: "r",
          expiry: format_expiry(expires_in),
          content_disposition: content_disposition_with(type: disposition, filename: filename),
          content_type: content_type
        ).to_s
      end

      def public_url(key, **)
        uri_for(key).to_s
      end


      def uri_for(key)
        client.generate_uri("#{container}/#{key}")
      end

      def blob_for(key)
        client.get_blob_properties(key)
      rescue AzureBlobStorage::Http::FileNotFoundError
        false
      end

      def format_expiry(expires_in)
        expires_in ? Time.now.utc.advance(seconds: expires_in).iso8601 : nil
      end

      # Reads the object for the given key in chunks, yielding each to the block.
      def stream(key)
        blob = blob_for(key)

        chunk_size = 5.megabytes
        offset = 0

        raise ActiveStorage::FileNotFoundError unless blob.present?

        while offset < blob.size
          chunk = client.get_blob(key, start: offset, end: offset + chunk_size - 1)
          yield chunk.force_encoding(Encoding::BINARY)
          offset += chunk_size
        end
      end

      def handle_errors
        yield
      rescue AzureBlobStorage::Http::IntegrityError
        raise ActiveStorage::IntegrityError
      rescue AzureBlobStorage::Http::FileNotFoundError
        raise ActiveStorage::FileNotFoundError
      end

      def custom_metadata_headers(metadata)
        AzureBlobStorage::Metadata.new(metadata).headers
      end
  end
end
