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
    IO.copy_stream(io, make_path_for(key))
    ensure_integrity_of(key, checksum) if checksum
  end

  def download(key)
    if block_given?
      File.open(path_for(key)) do |file|
        while data = file.binread(64.kilobytes)
          yield data
        end
      end
    else
      File.binread path_for(key)
    end
  end

  def delete(key)
    File.delete path_for(key) rescue Errno::ENOENT # Ignore files already deleted
  end

  def exist?(key)
    File.exist? path_for(key)
  end

  def url(key, expires_in:, disposition:, filename:)
    verified_key_with_expiration = ActiveStorage::VerifiedKeyWithExpiration.encode(key, expires_in: expires_in)

    if defined?(Rails) && defined?(Rails.application)
      Rails.application.routes.url_helpers.rails_disk_blob_path(verified_key_with_expiration, disposition: disposition, filename: filename)
    else
      "/rails/blobs/#{verified_key_with_expiration}/#{filename}?disposition=#{disposition}"
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
