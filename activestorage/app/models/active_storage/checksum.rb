# frozen_string_literal: true

class ActiveStorage::Checksum
  require "openssl"
  require "digest/crc32"
  require "digest/crc32c"
  require "digest/crc64"

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
        Digest::CRC32
      when :CRC32c
        Digest::CRC32c
      when :CRC64
        Digest::CRC64
      end
    end
  end
end
