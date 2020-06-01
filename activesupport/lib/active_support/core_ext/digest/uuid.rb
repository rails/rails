# frozen_string_literal: true

require "securerandom"
require "openssl"

module Digest
  module UUID
    DNS_NAMESPACE  = "k\xA7\xB8\x10\x9D\xAD\x11\xD1\x80\xB4\x00\xC0O\xD40\xC8" #:nodoc:
    URL_NAMESPACE  = "k\xA7\xB8\x11\x9D\xAD\x11\xD1\x80\xB4\x00\xC0O\xD40\xC8" #:nodoc:
    OID_NAMESPACE  = "k\xA7\xB8\x12\x9D\xAD\x11\xD1\x80\xB4\x00\xC0O\xD40\xC8" #:nodoc:
    X500_NAMESPACE = "k\xA7\xB8\x14\x9D\xAD\x11\xD1\x80\xB4\x00\xC0O\xD40\xC8" #:nodoc:

    # Generates a v5 non-random UUID (Universally Unique IDentifier).
    #
    # Using MD5 generates version 3 UUIDs; SHA1 generates version 5 UUIDs.
    # uuid_from_hash always generates the same UUID for a given name and namespace combination.
    #
    # See RFC 4122 for details of UUID at: https://www.ietf.org/rfc/rfc4122.txt
    def self.uuid_from_hash(hash_class, uuid_namespace, name)
      unless hash_class.is_a?(String)
        hash_class = hash_class.to_s.scan(/MD5|SHA1$/).first
        ActiveSupport::Deprecation.warn(<<~EOM)
          Passing a Hash Class to `uuid_from_hash` is deprecated and will be removed in Rails 6.2.
          Please pass a string instead (SHA1 or MD5).
        EOM
      end

      if hash_class == "MD5"
        version = 3
      elsif hash_class == "SHA1"
        version = 5
      else
        raise ArgumentError, "Expected SHA1 or MD5, got #{hash_class}."
      end

      hash = OpenSSL::Digest.new(hash_class)
      hash.update(uuid_namespace)
      hash.update(name)

      ary = hash.digest.unpack("NnnnnN")
      ary[2] = (ary[2] & 0x0FFF) | (version << 12)
      ary[3] = (ary[3] & 0x3FFF) | 0x8000

      "%08x-%04x-%04x-%04x-%04x%08x" % ary
    end

    # Convenience method for uuid_from_hash using Digest::MD5.
    def self.uuid_v3(uuid_namespace, name)
      uuid_from_hash("MD5", uuid_namespace, name)
    end

    # Convenience method for uuid_from_hash using Digest::SHA1.
    def self.uuid_v5(uuid_namespace, name)
      uuid_from_hash("SHA1", uuid_namespace, name)
    end

    # Convenience method for SecureRandom.uuid.
    def self.uuid_v4
      SecureRandom.uuid
    end
  end
end
