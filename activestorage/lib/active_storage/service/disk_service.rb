# frozen_string_literal: true

require "fileutils"
require "pathname"
require "openssl"
require "active_support/core_ext/numeric/bytes"

module ActiveStorage
  # = Active Storage \Disk \Service
  #
  # Wraps a local disk path as an Active Storage service. See ActiveStorage::Service for the generic API
  # documentation that applies to all services.
  class Service::DiskService < Service
    attr_accessor :root

    def initialize(root:, public: false, **options)
      @root = root
      @public = public
    end

    def upload(key, io, checksum: nil, **)
      instrument :upload, key: key, checksum: checksum do
        IO.copy_stream(io, make_path_for(key))
        ensure_integrity_of(key, checksum) if checksum
      end
    end

    def download(key, &block)
      if block_given?
        instrument :streaming_download, key: key do
          stream key, &block
        end
      else
        instrument :download, key: key do
          File.binread path_for(key)
        rescue Errno::ENOENT
          raise ActiveStorage::FileNotFoundError
        end
      end
    end

    def download_chunk(key, range)
      instrument :download_chunk, key: key, range: range do
        File.open(path_for(key), "rb") do |file|
          file.seek range.begin
          file.read range.size
        end
      rescue Errno::ENOENT
        raise ActiveStorage::FileNotFoundError
      end
    end

    def delete(key)
      instrument :delete, key: key do
        File.delete path_for(key)
      rescue Errno::ENOENT
        # Ignore files already deleted
      end
    end

    def delete_prefixed(prefix)
      instrument :delete_prefixed, prefix: prefix do
        Dir.glob(path_for("#{prefix}*")).each do |path|
          FileUtils.rm_rf(path)
        end
      end
    end

    def exist?(key)
      instrument :exist, key: key do |payload|
        answer = File.exist? path_for(key)
        payload[:exist] = answer
        answer
      end
    end

    def url_for_direct_upload(key, expires_in:, content_type:, content_length:, checksum:, custom_metadata: {})
      instrument :url, key: key do |payload|
        verified_token_with_expiration = ActiveStorage.verifier.generate(
          {
            key: key,
            content_type: content_type,
            content_length: content_length,
            checksum: checksum,
            service_name: name
          },
          expires_in: expires_in,
          purpose: :blob_token
        )

        url_helpers.update_rails_disk_service_url(verified_token_with_expiration, url_options).tap do |generated_url|
          payload[:url] = generated_url
        end
      end
    end

    def headers_for_direct_upload(key, content_type:, **)
      { "Content-Type" => content_type }
    end

    def path_for(key) # :nodoc:
      File.join root, folder_for(key), key
    end

    def compose(source_keys, destination_key, **)
      File.open(make_path_for(destination_key), "w") do |destination_file|
        source_keys.each do |source_key|
          File.open(path_for(source_key), "rb") do |source_file|
            IO.copy_stream(source_file, destination_file)
          end
        end
      end
    end

    private
      def private_url(key, expires_in:, filename:, content_type:, disposition:, **)
        generate_url(key, expires_in: expires_in, filename: filename, content_type: content_type, disposition: disposition)
      end

      def public_url(key, filename:, content_type: nil, disposition: :attachment, **)
        generate_url(key, expires_in: nil, filename: filename, content_type: content_type, disposition: disposition)
      end

      def generate_url(key, expires_in:, filename:, content_type:, disposition:)
        content_disposition = content_disposition_with(type: disposition, filename: filename)
        verified_key_with_expiration = ActiveStorage.verifier.generate(
          {
            key: key,
            disposition: content_disposition,
            content_type: content_type,
            service_name: name
          },
          expires_in: expires_in,
          purpose: :blob_key
        )

        if url_options.blank?
          raise ArgumentError, "Cannot generate URL for #{filename} using Disk service, please set ActiveStorage::Current.url_options."
        end

        url_helpers.rails_disk_service_url(verified_key_with_expiration, filename: filename, **url_options)
      end


      def stream(key)
        File.open(path_for(key), "rb") do |file|
          while data = file.read(5.megabytes)
            yield data
          end
        end
      rescue Errno::ENOENT
        raise ActiveStorage::FileNotFoundError
      end

      def folder_for(key)
        [ key[0..1], key[2..3] ].join("/")
      end

      def make_path_for(key)
        path_for(key).tap { |path| FileUtils.mkdir_p File.dirname(path) }
      end

      def ensure_integrity_of(key, checksum)
        unless ActiveStorage.checksum_implementation.file(path_for(key)).base64digest == checksum
          delete key
          raise ActiveStorage::IntegrityError
        end
      end

      def url_helpers
        @url_helpers ||= Rails.application.routes.url_helpers
      end

      def url_options
        ActiveStorage::Current.url_options
      end
  end
end
