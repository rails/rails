# frozen_string_literal: true

gem "azure-storage-blob", "~> 2.0"

require "active_support/core_ext/numeric/bytes"
require "azure/storage/blob"
require "azure/storage/blob/default"
require "azure/storage/common/core/auth/shared_access_signature"

module ActiveStorage
  # Wraps the Microsoft Azure Storage Blob Service as an Active Storage service.
  # See ActiveStorage::Service for the generic API documentation that applies to all services.
  class Service::AzureStorageService < Service
    # Client that authenticates to Azure Storage via Azure Active Directory
    # See https://docs.microsoft.com/en-us/azure/storage/common/storage-auth-aad
    class AzureActiveDirectoryClient
      attr_reader :storage_account_name, :options, :auth_context, :client_credential
      attr_accessor :user_delegation_key

      def initialize(storage_account_name, **options)
        require "adal"
        gem "adal", "~> 1.0"

        tenant_id = options.delete(:tenant_id) || ""
        client_id = options.delete(:client_id) || ""
        client_secret = options.delete(:client_secret) || ""

        if tenant_id.empty? || client_id.empty? || client_secret.empty?
          raise ArgumentError, "all of tenant_id, client_id, and client_secret must be provided"
        end

        @storage_account_name = storage_account_name
        @options = options
        @auth_context = ADAL::AuthenticationContext.new("login.microsoftonline.com", tenant_id)
        @client_credential = ADAL::ClientCredential.new(client_id, client_secret)
        @user_delegation_key = nil
      end

      def blob_service
        token = @auth_context.acquire_token_for_client("https://storage.azure.com/", @client_credential)
        token_credential = Azure::Storage::Common::Core::TokenCredential.new token.access_token
        token_signer = Azure::Storage::Common::Core::Auth::TokenSigner.new token_credential
        client = Azure::Storage::Common::Client.create(storage_account_name: @storage_account_name, signer: token_signer)
        Azure::Storage::Blob::BlobService.new(client: client, api_version: "2018-11-09", **@options)
      end

      def shared_access_signature
        if @user_delegation_key.nil? || @user_delegation_key.signed_expiry.to_datetime <= DateTime.now
          now = Time.now
          @user_delegation_key = blob_service.get_user_delegation_key(now - 5.minutes, now + 6.days)
        end
        Azure::Storage::Common::Core::Auth::SharedAccessSignature.new(@storage_account_name, "", @user_delegation_key)
      end
    end

    # Client that authenticates to Azure Storage via account access keys
    # See https://docs.microsoft.com/en-us/rest/api/storageservices/authorize-with-shared-key
    class AccessKeyClient
      attr_reader :blob_service, :shared_access_signature

      def initialize(storage_account_name, storage_access_key, **options)
        @blob_service = Azure::Storage::Blob::BlobService.create(storage_account_name: storage_account_name, storage_access_key: storage_access_key, **options)
        @shared_access_signature = Azure::Storage::Common::Core::Auth::SharedAccessSignature.new(storage_account_name, storage_access_key)
      end
    end

    attr_reader :clients, :container

    def initialize(storage_account_name:, storage_access_key: nil, container:, public: false, **options)
      @clients = storage_access_key.nil? || storage_access_key.empty? \
        ? AzureActiveDirectoryClient.new(storage_account_name, **options) \
        : AccessKeyClient.new(storage_account_name, storage_access_key, **options)
      @container = container
      @public = public
    end

    def upload(key, io, checksum: nil, filename: nil, content_type: nil, disposition: nil, **)
      instrument :upload, key: key, checksum: checksum do
        handle_errors do
          content_disposition = content_disposition_with(filename: filename, type: disposition) if disposition && filename

          client.create_block_blob(container, key, IO.try_convert(io) || io, content_md5: checksum, content_type: content_type, content_disposition: content_disposition)
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
            _, io = client.get_blob(container, key)
            io.force_encoding(Encoding::BINARY)
          end
        end
      end
    end

    def download_chunk(key, range)
      instrument :download_chunk, key: key, range: range do
        handle_errors do
          _, io = client.get_blob(container, key, start_range: range.begin, end_range: range.exclude_end? ? range.end - 1 : range.end)
          io.force_encoding(Encoding::BINARY)
        end
      end
    end

    def delete(key)
      instrument :delete, key: key do
        client.delete_blob(container, key)
      rescue Azure::Core::Http::HTTPError => e
        raise unless e.type == "BlobNotFound"
        # Ignore files already deleted
      end
    end

    def delete_prefixed(prefix)
      instrument :delete_prefixed, prefix: prefix do
        marker = nil

        loop do
          results = client.list_blobs(container, prefix: prefix, marker: marker)

          results.each do |blob|
            client.delete_blob(container, blob.name)
          end

          break unless marker = results.continuation_token.presence
        end
      end
    end

    def exist?(key)
      instrument :exist, key: key do |payload|
        answer = blob_for(key).present?
        payload[:exist] = answer
        answer
      end
    end

    def url_for_direct_upload(key, expires_in:, content_type:, content_length:, checksum:)
      instrument :url, key: key do |payload|
        generated_url = signer.signed_uri(
          uri_for(key), false,
          service: "b",
          permissions: "rw",
          expiry: format_expiry(expires_in)
        ).to_s

        payload[:url] = generated_url

        generated_url
      end
    end

    def headers_for_direct_upload(key, content_type:, checksum:, filename: nil, disposition: nil, **)
      content_disposition = content_disposition_with(type: disposition, filename: filename) if filename

      { "Content-Type" => content_type, "Content-MD5" => checksum, "x-ms-blob-content-disposition" => content_disposition, "x-ms-blob-type" => "BlockBlob" }
    end

    def client
      @clients.blob_service
    end

    def signer
      @clients.shared_access_signature
    end

    private
      def private_url(key, expires_in:, filename:, disposition:, content_type:, **)
        signer.signed_uri(
          uri_for(key), false,
          service: "b",
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
        client.get_blob_properties(container, key)
      rescue Azure::Core::Http::HTTPError
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

        while offset < blob.properties[:content_length]
          _, chunk = client.get_blob(container, key, start_range: offset, end_range: offset + chunk_size - 1)
          yield chunk.force_encoding(Encoding::BINARY)
          offset += chunk_size
        end
      end

      def handle_errors
        yield
      rescue Azure::Core::Http::HTTPError => e
        case e.type
        when "BlobNotFound"
          raise ActiveStorage::FileNotFoundError
        when "Md5Mismatch"
          raise ActiveStorage::IntegrityError
        else
          raise
        end
      end
  end
end
