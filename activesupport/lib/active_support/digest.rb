# frozen_string_literal: true

require "openssl"

module ActiveSupport
  class Digest #:nodoc:
    class <<self
      def hash_digest_class
        @hash_digest_class ||= "MD5"
      end

      def hash_digest_class=(klass)
        unless klass.is_a?(String)
          klass = klass.to_s.split("::").last.to_s
          ActiveSupport::Deprecation.warn(<<~EOM)
            Passing a Digest Class to `hash_digest_class=` is deprecated and will be removed in future
            versions of Rails. Please pass a string instead (SHA1, SHA256, MD5, etc).
          EOM
        end

        raise ArgumentError, "#{klass} is unsupported by OpenSSL::Digest" unless OpenSSL::Digest.const_defined?(klass)
        @hash_digest_class = klass
      end

      def hexdigest(arg)
        OpenSSL::Digest.hexdigest(hash_digest_class, arg)[0...32]
      end
    end
  end
end
