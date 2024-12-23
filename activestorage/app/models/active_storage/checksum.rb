# frozen_string_literal: true

class ActiveStorage::Checksum
  require "openssl"
  require "digest/crc32"
  require "digest/crc32c"
  require "digest/crc64"

  SUPPORTED_CHECKSUMS = {
    MD5: OpenSSL::Digest::MD5,
    SHA1: OpenSSL::Digest::SHA1,
    SHA256: OpenSSL::Digest::SHA256,
    CRC32: Digest::CRC32,
    CRC32c: Digest::CRC32c,
    CRC64: Digest::CRC64
  }

  class << self
    # Returns class of integrity checksum algorithm
    #   ActiveStorage::Checksum.for(:MD5) # => OpenSSL::Digest::MD5

    def for(checksum_algorithm)
      SUPPORTED_CHECKSUMS[checksum_algorithm]
    end
  end
end
