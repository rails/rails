# frozen_string_literal: true

gem "google-cloud-storage", "~> 1.11"
require "google/apis/iamcredentials_v1"
require "google/cloud/storage"

module ActiveStorage
  # Wraps the Google Cloud Storage as an Active Storage service. See ActiveStorage::Service for the generic API
  # documentation that applies to all services.
  class Service::GCSService < Service
    class MetadataServerError < ActiveStorage::Error; end
    class MetadataServerNotFoundError < ActiveStorage::Error; end

    def initialize(public: false, **config)
      @config = config
      @public = public
    end

    def upload(key, io, checksum: nil, content_type: nil, disposition: nil, filename: nil, custom_metadata: {})
      instrument :upload, key: key, checksum: checksum do
        # GCS's signed URLs don't include params such as response-content-type response-content_disposition
        # in the signature, which means an attacker can modify them and bypass our effort to force these to
        # binary and attachment when the file's content type requires it. The only way to force them is to
        # store them as object's metadata.
        content_disposition = content_disposition_with(type: disposition, filename: filename) if disposition && filename
        bucket.create_file(io, key, md5: checksum, cache_control: @config[:cache_control], content_type: content_type, content_disposition: content_disposition, metadata: custom_metadata)
      rescue Google::Cloud::InvalidArgumentError
        raise ActiveStorage::IntegrityError
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
        rescue Google::Cloud::NotFoundError
          raise ActiveStorage::FileNotFoundError
        end
      end
    end

    def update_metadata(key, content_type:, disposition: nil, filename: nil, custom_metadata: {})
      instrument :update_metadata, key: key, content_type: content_type, disposition: disposition do
        file_for(key).update do |file|
          file.content_type = content_type
          file.content_disposition = content_disposition_with(type: disposition, filename: filename) if disposition && filename
          file.metadata = custom_metadata
        end
      end
    end

    def download_chunk(key, range)
      instrument :download_chunk, key: key, range: range do
        file_for(key).download(range: range).string
      rescue Google::Cloud::NotFoundError
        raise ActiveStorage::FileNotFoundError
      end
    end

    def delete(key)
      instrument :delete, key: key do
        file_for(key).delete
      rescue Google::Cloud::NotFoundError
        # Ignore files already deleted
      end
    end

    def delete_prefixed(prefix)
      instrument :delete_prefixed, prefix: prefix do
        bucket.files(prefix: prefix).all do |file|
          file.delete
        rescue Google::Cloud::NotFoundError
          # Ignore concurrently-deleted files
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

    def url_for_direct_upload(key, expires_in:, checksum:, custom_metadata: {}, **)
      instrument :url, key: key do |payload|
        headers = {}
        version = :v2

        if @config[:cache_control].present?
          headers["Cache-Control"] = @config[:cache_control]
          # v2 signing doesn't support non `x-goog-` headers. Only switch to v4 signing
          # if necessary for back-compat; v4 limits the expiration of the URL to 7 days
          # whereas v2 has no limit
          version = :v4
        end

        headers.merge!(custom_metadata_headers(custom_metadata))

        args = {
          content_md5: checksum,
          expires: expires_in,
          headers: headers,
          method: "PUT",
          version: version,
        }

        if @config[:iam]
          args[:issuer] = issuer
          args[:signer] = signer
        end

        generated_url = bucket.signed_url(key, **args)

        payload[:url] = generated_url

        generated_url
      end
    end

    def headers_for_direct_upload(key, checksum:, filename: nil, disposition: nil, custom_metadata: {}, **)
      content_disposition = content_disposition_with(type: disposition, filename: filename) if filename

      headers = { "Content-MD5" => checksum, "Content-Disposition" => content_disposition, **custom_metadata_headers(custom_metadata) }
      if @config[:cache_control].present?
        headers["Cache-Control"] = @config[:cache_control]
      end

      headers
    end

    def compose(source_keys, destination_key, filename: nil, content_type: nil, disposition: nil, custom_metadata: {})
      bucket.compose(source_keys, destination_key).update do |file|
        file.content_type = content_type
        file.content_disposition = content_disposition_with(type: disposition, filename: filename) if disposition && filename
        file.metadata = custom_metadata
      end
    end

    private
      def private_url(key, expires_in:, filename:, content_type:, disposition:, **)
        args = {
          expires: expires_in,
          query: {
            "response-content-disposition" => content_disposition_with(type: disposition, filename: filename),
            "response-content-type" => content_type
          }
        }

        if @config[:iam]
          args[:issuer] = issuer
          args[:signer] = signer
        end

        file_for(key).signed_url(**args)
      end

      def public_url(key, **)
        file_for(key).public_url
      end


      attr_reader :config

      def file_for(key, skip_lookup: true)
        bucket.file(key, skip_lookup: skip_lookup)
      end

      # Reads the file for the given key in chunks, yielding each to the block.
      def stream(key)
        file = file_for(key, skip_lookup: false)

        chunk_size = 5.megabytes
        offset = 0

        raise ActiveStorage::FileNotFoundError unless file.present?

        while offset < file.size
          yield file.download(range: offset..(offset + chunk_size - 1)).string
          offset += chunk_size
        end
      end

      def bucket
        @bucket ||= client.bucket(config.fetch(:bucket), skip_lookup: true)
      end

      def client
        @client ||= Google::Cloud::Storage.new(**config.except(:bucket, :cache_control, :iam, :gsa_email))
      end

      def issuer
        @issuer ||= if @config[:gsa_email]
          @config[:gsa_email]
        else
          uri = URI.parse("http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email")
          http = Net::HTTP.new(uri.host, uri.port)
          request = Net::HTTP::Get.new(uri.request_uri)
          request["Metadata-Flavor"] = "Google"

          begin
            response = http.request(request)
          rescue SocketError
            raise MetadataServerNotFoundError
          end

          if response.is_a?(Net::HTTPSuccess)
            response.body
          else
            raise MetadataServerError
          end
        end
      end

      def signer
        # https://googleapis.dev/ruby/google-cloud-storage/latest/Google/Cloud/Storage/Project.html#signed_url-instance_method
        lambda do |string_to_sign|
          iam_client = Google::Apis::IamcredentialsV1::IAMCredentialsService.new

          scopes = ["https://www.googleapis.com/auth/iam"]
          iam_client.authorization = Google::Auth.get_application_default(scopes)

          request = Google::Apis::IamcredentialsV1::SignBlobRequest.new(
            payload: string_to_sign
          )
          resource = "projects/-/serviceAccounts/#{issuer}"
          response = iam_client.sign_service_account_blob(resource, request)
          response.signed_blob
        end
      end

      def custom_metadata_headers(metadata)
        metadata.transform_keys { |key| "x-goog-meta-#{key}" }
      end
  end
end
