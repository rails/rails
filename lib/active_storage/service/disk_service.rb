require "fileutils"
require "pathname"
require "digest/md5"
require "active_support/core_ext/numeric/bytes"

class ActiveStorage::Service::DiskService < ActiveStorage::Service
  attr_reader :root

  def initialize(root:)
    @root = root
  end

  def upload(key, io, checksum: nil)
    instrument :upload, key, checksum: checksum do
      IO.copy_stream(io, make_path_for(key))
      ensure_integrity_of(key, checksum) if checksum
    end
  end

  def download(key)
    if block_given?
      instrument :streaming_download, key do
        File.open(path_for(key)) do |file|
          while data = file.binread(64.kilobytes)
            yield data
          end
        end
      end
    else
      instrument :download, key do
        File.binread path_for(key)
      end
    end
  end

  def delete(key)
    instrument :delete, key do
      begin
        File.delete path_for(key)
      rescue Errno::ENOENT
        # Ignore files already deleted
      end
    end
  end

  def exist?(key)
    instrument :exist, key do |payload|
      answer = File.exist? path_for(key)
      payload[:exist] = answer
      answer
    end
  end

  def url(key, expires_in:, disposition:, filename:)
    instrument :url, key do |payload|
      verified_key_with_expiration = ActiveStorage::VerifiedKeyWithExpiration.encode(key, expires_in: expires_in)

      generated_url = 
        if defined?(Rails) && defined?(Rails.application)
          Rails.application.routes.url_helpers.rails_disk_blob_path(verified_key_with_expiration, disposition: disposition, filename: filename)
        else
          "/rails/blobs/#{verified_key_with_expiration}/#{filename}?disposition=#{disposition}"
        end

      payload[:url] = generated_url
      
      generated_url
    end
  end

  private
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
        raise ActiveStorage::IntegrityError
      end
    end
end
