require "fileutils"
require "pathname"

class ActiveFile::Sites::DiskSite < ActiveFile::Site
  class_attribute :verifier, default: -> { Rails.application.message_verifier('ActiveFile::DiskSite') }

  class << self
    def generate_verifiable_key(key, expires_in:)
      VerifiedKeyWithExpiration
    end
  end

  class VerifiableKeyWithExpiration
    def initialize(verifiable_key_with_expiration)
      verified_key_with_expiration = ActiveFile::Sites::DiskSite.verify(verifiable_key_with_expiration)

      @key        = verified_key_with_expiration[:key]
      @expires_at = verified_key_with_expiration[:expires_at]
    end

    def expired?
      @expires_at && Time.now.utc > @expires_at
    end

    def decoded
      key
    end
  end

  class VerifiedKeyWithExpiration
    def initialize(key, expires_in: nil)
      @key = key
      @expires_at = Time.now.utc.advance(sec: expires_in)
    end

    def encoded
      ActiveFile::Sites::DiskSite.verify.generate({ key: @key, expires_at: @expires_at })
    end
  end

  attr_reader :root

  def initialize(root:)
    @root = root
  end


  def upload(key, data)
    File.open(make_path_for(key), "wb") do |file|
      while chunk = data.read(65536)
        file.write(chunk)
      end
    end
  end

  def download(key)
    if block_given?
      File.open(path_for(key)) do |file|
        while data = file.read(65536)
          yield data
        end
      end
    else
      File.open path_for(key), &:read
    end
  end

  def delete(key)
    File.delete path_for(key)
  end

  def exists?(key)
    File.exist? path_for(key)
  end


  def url(key, disposition:, expires_in: nil)
    if defined?(Rails)
      Rails.application.routes.url_helpers.rails_disk_blob_path(key)
    else
      "/rails/blobs/#{key}"
    end
  end

  def byte_size(key)
    File.size path_for(key)
  end

  def checksum(key)
    Digest::MD5.file(path_for(key)).hexdigest
  end


  private
    def verifiable_key_with_expiration(key, expires_in: nil)
      verifier.generate key: key, expires_at: Time.now.utc.advance(sec: expires_in)
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
end
