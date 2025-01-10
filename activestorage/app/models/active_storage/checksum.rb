# frozen_string_literal: true

class ActiveStorage::Checksum
  require "openssl"

  attr_accessor :crc32, :crc32c, :crc64

  class << self
    # Returns class of integrity checksum algorithm
    #   ActiveStorage::Checksum.for(:MD5) # => OpenSSL::Digest::MD5
    def for(checksum_algorithm)
      case checksum_algorithm
      when :MD5
        ActiveStorage.md5_checksum_implementation
      when :SHA1
        OpenSSL::Digest::SHA1
      when :SHA256
        OpenSSL::Digest::SHA256
      when :CRC32
        return @crc32 if @crc32
        begin
          require "digest/crc32"
        rescue LoadError
          raise LoadError, 'digest/crc32 not loaded. Please add `gem "digest-crc"` to your gemfile.'
        end
        @crc32 = Digest::CRC32
      when :CRC32c
        return @crc32c if @crc32c
        begin
          require "digest/crc32c"
        rescue LoadError
          raise LoadError, 'digest/crc32c not loaded. Please add `gem "digest-crc"` to your gemfile.'
        end
        @crc32c = Digest::CRC32c
      when :CRC64
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
end
