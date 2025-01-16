# frozen_string_literal: true

class ActiveStorage::Checksum # :nodoc:
  require "openssl"

  attr_accessor :crc32, :crc32c, :crc64, :md5

  class << self
    def implementation_class(checksum_algorithm)
      case checksum_algorithm
      when :MD5
        md5
      when :SHA1
        sha1
      when :SHA256
        sha256
      when :CRC32
        crc32
      when :CRC32c
        crc32c
      when :CRC64
        crc64
      end
    end

    def file(file, algorithm)
      implementation_class(algorithm).file(file).base64digest
    end

    def base64digest(io, algorithm)
      implementation_class(algorithm).base64digest(io)
    end

    def compute_checksum_in_chunks(io, service)
      raise ArgumentError, "io must be rewindable" unless io.respond_to?(:rewind)
      return unless service

      implementation_class(service.checksum_algorithm).new.tap do |checksum|
          read_buffer = "".b
          while io.read(5.megabytes, read_buffer)
            checksum << read_buffer
          end

          io.rewind
        end.base64digest
    end

    def md5
      return @md5 if @md5
      @md5 = OpenSSL::Digest::MD5
      @md5.hexdigest("test")
      OpenSSL::Digest::MD5
    rescue # OpenSSL may have MD5 disabled
      require "digest/md5"
      @md5 = Digest::MD5
    end

    def sha1
      OpenSSL::Digest::SHA1
    end

    def sha256
      OpenSSL::Digest::SHA256
    end

    def crc32
      return @crc32 if @crc32
      begin
        require "digest/crc32"
      rescue LoadError
        raise LoadError, 'digest/crc32 not loaded. Please add `gem "digest-crc"` to your gemfile.'
      end
      @crc32 = Digest::CRC32
    end

    def crc32c
      return @crc32c if @crc32c
      begin
        require "digest/crc32c"
      rescue LoadError
        raise LoadError, 'digest/crc32c not loaded. Please add `gem "digest-crc"` to your gemfile.'
      end
      @crc32c = Digest::CRC32c
    end

    def crc64
      return @crc64 if @crc64
      begin
        require "digest/crc64"
      rescue LoadError
        raise LoadError, 'digest/crc64 not loaded. Please add `gem "digest-crc"` to your gemfile.'
      end
      @crc64 = Digest::CRC64
    end
  end
end
