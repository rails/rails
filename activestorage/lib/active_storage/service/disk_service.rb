# frozen_string_literal: true

require "fileutils"
require "pathname"
require "digest/md5"
require "active_support/core_ext/numeric/bytes"

module ActiveStorage
  # Wraps a local disk path as an Active Storage service. See ActiveStorage::Service for the generic API
  # documentation that applies to all services.
  class Service::DiskService < Service
    attr_reader :root, :host, :routes

    def initialize(root:, host: nil)
      @root, @host = root, host
      @routes = Rails.application.routes.url_helpers
    end

    def upload(key, io, checksum: nil)
      instrument :upload, key: key, checksum: checksum do
        IO.copy_stream(io, make_path_for(key))
        ensure_integrity_of(key, checksum) if checksum
      end
    end

    def download(key)
      if block_given?
        instrument :streaming_download, key: key do
          File.open(path_for(key), "rb") do |file|
            while data = file.read(64.kilobytes)
              yield data
            end
          end
        end
      else
        instrument :download, key: key do
          File.binread path_for(key)
        end
      end
    end

    def delete(key)
      instrument :delete, key: key do
        begin
          File.delete path_for(key)
        rescue Errno::ENOENT
          # Ignore files already deleted
        end
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

    def url(key, expires_in:, filename:, disposition:, content_type:)
      instrument :url, key: key do |payload|
        signed_key = ActiveStorage.verifier.generate(key, expires_in: expires_in, purpose: :blob_key)

        options = {
          filename: filename,
          disposition: content_disposition_with(type: disposition, filename: filename),
          content_type: content_type
        }

        payload[:url] = rails_disk_service_url(signed_key, options)
        payload[:url]
      end
    end

    def url_for_direct_upload(key, expires_in:, content_type:, content_length:, checksum:)
      instrument :url, key: key do |payload|
        message = {
          key: key,
          content_type: content_type,
          content_length: content_length,
          checksum: checksum
        }

        signed_message = ActiveStorage.verifier.generate(message, expires_in: expires_in, purpose: :blob_token)

        payload[:url] = update_rails_disk_service_url(signed_message)
        payload[:url]
      end
    end

    def headers_for_direct_upload(key, content_type:, **)
      { "Content-Type" => content_type }
    end

    private
      def rails_disk_service_url(signed_key, options)
        if host
          options[:host] = host
          routes.rails_disk_service_url(signed_key, options)
        else
          routes.rails_disk_service_path(signed_key, options)
        end
      end

      def update_rails_disk_service_url(signed_message)
        if host
          routes.update_rails_disk_service_url(signed_message, host: host)
        else
          routes.update_rails_disk_service_path(signed_message)
        end
      end

      def path_for(key)
        File.join root, folder_for(key), key
      end

      def folder_for(key)
        [ key[0..1], key[2..3] ].join("/")
      end

      def make_path_for(key)
        path_for(key).tap { |path| FileUtils.mkdir_p File.dirname(path) }
      end

      def ensure_integrity_of(key, checksum)
        unless Digest::MD5.file(path_for(key)).base64digest == checksum
          delete key
          raise ActiveStorage::IntegrityError
        end
      end
  end
end
