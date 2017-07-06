require "fileutils"
require "pathname"

class ActiveStorage::Service::DiskService < ActiveStorage::Service
  CHUNK_SIZE = 65536

  attr_reader :root

  def initialize(root:)
    @root = root
  end

  def upload(key, io)
    File.open(make_path_for(key), "wb") do |file|
      while chunk = io.read(CHUNK_SIZE)
        file.write(chunk)
      end
    end
  end

  def download(key)
    if block_given?
      File.open(path_for(key)) do |file|
        while data = file.read(CHUNK_SIZE)
          yield data
        end
      end
    else
      File.open path_for(key), &:read
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
      Rails.application.routes.url_helpers.rails_disk_blob_path(verified_key_with_expiration, disposition: disposition)
    else
      "/rails/blobs/#{verified_key_with_expiration}?disposition=#{disposition}"
    end
  end

  def byte_size(key)
    File.size path_for(key)
  end

  def checksum(key)
    Digest::MD5.file(path_for(key)).hexdigest
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
end
