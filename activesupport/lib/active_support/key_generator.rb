require 'mutex_m'
require 'openssl'

module ActiveSupport
  # KeyGenerator is a simple wrapper around OpenSSL's implementation of PBKDF2
  # It can be used to derive a number of keys for various purposes from a given secret.
  # This lets rails applications have a single secure secret, but avoid reusing that
  # key in multiple incompatible contexts.
  class KeyGenerator
    def initialize(secret, options = {})
      @secret = secret
      # The default iterations are higher than required for our key derivation uses
      # on the off chance someone uses this for password storage
      @iterations = options[:iterations] || 2**16
    end

    # Returns a derived key suitable for use.  The default key_size is chosen
    # to be compatible with the default settings of ActiveSupport::MessageVerifier.
    # i.e. OpenSSL::Digest::SHA1#block_length
    def generate_key(salt, key_size=64)
      OpenSSL::PKCS5.pbkdf2_hmac_sha1(@secret, salt, @iterations, key_size)
    end
  end

  class CachingKeyGenerator
    def initialize(key_generator)
      @key_generator = key_generator
      @cache_keys = {}.extend(Mutex_m)
    end

    def generate_key(salt, key_size=64)
      @cache_keys.synchronize do
        @cache_keys["#{salt}#{key_size}"] ||= @key_generator.generate_key(salt, key_size)
      end
    end
  end

  class DummyKeyGenerator
    SECRET_MIN_LENGTH = 30 # Characters

    def initialize(secret)
      ensure_secret_secure(secret)
      @secret = secret
    end

    def generate_key(salt)
      @secret
    end

    private

    # To prevent users from using something insecure like "Password" we make sure that the
    # secret they've provided is at least 30 characters in length.
    def ensure_secret_secure(secret)
      if secret.blank?
        raise ArgumentError, "A secret is required to generate an " +
          "integrity hash for cookie session data. Use " +
          "config.secret_key_base = \"some secret phrase of at " +
          "least #{SECRET_MIN_LENGTH} characters\"" +
          "in config/initializers/secret_token.rb"
      end

      if secret.length < SECRET_MIN_LENGTH
        raise ArgumentError, "Secret should be something secure, " +
          "like \"#{SecureRandom.hex(16)}\". The value you " +
          "provided, \"#{secret}\", is shorter than the minimum length " +
          "of #{SECRET_MIN_LENGTH} characters"
      end
    end
  end
end
