# frozen_string_literal: true

require "securerandom"

module ActiveRecord
  module Encryption
    # Utility for generating and deriving random keys.
    class KeyGenerator
      # Returns a random key. The key will have a size in bytes of +:length+ (configured +Cipher+'s length by default)
      def generate_random_key(length: key_length)
        SecureRandom.random_bytes(length)
      end

      # Returns a random key in hexadecimal format. The key will have a size in bytes of +:length+ (configured +Cipher+'s
      # length by default)
      #
      # Hexadecimal format is handy for representing keys as printable text. To maximize the space of characters used, it is
      # good practice including not printable characters. Hexadecimal format ensures that generated keys are representable with
      # plain text
      #
      # To convert back to the original string with the desired length:
      #
      #   [ value ].pack("H*")
      def generate_random_hex_key(length: key_length)
        generate_random_key(length: length).unpack("H*")[0]
      end

      # Derives a key from the given password. The key will have a size in bytes of +:length+ (configured +Cipher+'s length
      # by default)
      #
      # The generated key will be salted with the value of +ActiveRecord::Encryption.key_derivation_salt+
      def derive_key_from(password, length: key_length)
        ActiveSupport::KeyGenerator.new(password).generate_key(ActiveRecord::Encryption.config.key_derivation_salt, length)
      end

      private
        def key_length
          @key_length ||= ActiveRecord::Encryption.cipher.key_length
        end
    end
  end
end
