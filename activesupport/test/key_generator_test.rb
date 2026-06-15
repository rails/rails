# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/testing/ractors_assertions"

begin
  require "openssl"
  OpenSSL::PKCS5
rescue LoadError, NameError
  $stderr.puts "Skipping KeyGenerator test: broken OpenSSL install"
else

  class KeyGeneratorTest < ActiveSupport::TestCase
    class InvalidDigest; end

    def setup
      @secret    = SecureRandom.hex(64)
      @generator = ActiveSupport::KeyGenerator.new(@secret, iterations: 2)
    end

    test "Generating a key of the default length" do
      derived_key = @generator.generate_key("some_salt")
      assert_kind_of String, derived_key
      assert_equal 64, derived_key.length, "Should have generated a key of the default size"
    end

    test "Generating a key of an alternative length" do
      derived_key = @generator.generate_key("some_salt", 32)
      assert_kind_of String, derived_key
      assert_equal 32, derived_key.length, "Should have generated a key of the right size"
    end

    test "Expected results" do
      # For any given set of inputs, this method must continue to return
      # the same output: if it changes, any existing values relying on a
      # key would break.

      expected = "b129376f68f1ecae788d7433310249d65ceec090ecacd4c872a3a9e9ec78e055739be5cc6956345d5ae38e7e1daa66f1de587dc8da2bf9e8b965af4b3918a122"
      assert_equal expected, ActiveSupport::KeyGenerator.new("0" * 64).generate_key("some_salt").unpack1("H*")

      expected = "b129376f68f1ecae788d7433310249d65ceec090ecacd4c872a3a9e9ec78e055"
      assert_equal expected, ActiveSupport::KeyGenerator.new("0" * 64).generate_key("some_salt", 32).unpack1("H*")

      expected = "cbea7f7f47df705967dc508f4e446fd99e7797b1d70011c6899cd39bbe62907b8508337d678505a7dc8184e037f1003ba3d19fc5d829454668e91d2518692eae"
      assert_equal expected, ActiveSupport::KeyGenerator.new("0" * 64, iterations: 2).generate_key("some_salt").unpack1("H*")
    end

    test "With custom hash digest class" do
      original_hash_digest_class = ActiveSupport::KeyGenerator.hash_digest_class

      ActiveSupport::KeyGenerator.hash_digest_class = ::OpenSSL::Digest::SHA256

      expected = "c92322ad55ee691520e8e0f279b53e7a5cc9c1f8efca98295ae252b04cc6e2274c3aaf75ef53b260a6dc548f3e5fbb8af0edf10e7663cf7054c35bcc12835fc0"
      assert_equal expected, ActiveSupport::KeyGenerator.new("0" * 64).generate_key("some_salt").unpack1("H*")
    ensure
      ActiveSupport::KeyGenerator.hash_digest_class = original_hash_digest_class
    end

    test "Raises if given a non digest instance" do
      assert_raises(ArgumentError) { ActiveSupport::KeyGenerator.hash_digest_class = InvalidDigest }
      assert_raises(ArgumentError) { ActiveSupport::KeyGenerator.hash_digest_class = InvalidDigest.new }
    end

    test "inspect does not show secrets" do
      assert_match(/\A#<ActiveSupport::KeyGenerator:0x[0-9a-f]+>\z/, @generator.inspect)
    end
  end

  class CachingKeyGeneratorTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::RactorsAssertions

    def setup
      @secret    = SecureRandom.hex(64)
      @generator = ActiveSupport::KeyGenerator.new(@secret, iterations: 2)
      @caching_generator = ActiveSupport::CachingKeyGenerator.new(@generator)
    end

    test "Generating a cached key for same salt and key size" do
      derived_key = @caching_generator.generate_key("some_salt", 32)
      cached_key = @caching_generator.generate_key("some_salt", 32)

      assert_equal derived_key, cached_key
      assert_equal derived_key.object_id, cached_key.object_id
    end

    test "Does not cache key for different salt" do
      derived_key = @caching_generator.generate_key("some_salt", 32)
      different_salt_key = @caching_generator.generate_key("other_salt", 32)

      assert_not_equal derived_key, different_salt_key
    end

    test "Does not cache key for different length" do
      derived_key = @caching_generator.generate_key("some_salt", 32)
      different_length_key = @caching_generator.generate_key("some_salt", 64)

      assert_not_equal derived_key, different_length_key
    end

    test "Does not cache key for different salts and lengths that are different but are equal when concatenated" do
      derived_key = @caching_generator.generate_key("13", 37)
      different_length_key = @caching_generator.generate_key("1", 337)

      assert_not_equal derived_key, different_length_key
    end

    test "CachingKeyGenerator can work across ractors" do
      # OpenSSL::Digest are not Ractor-safe, but the fix is already merged upstream. This test can be updated
      # to use our implementation once a version of Ruby ships with ruby/openssl@502bc6c
      key_generator = Class.new(ActiveSupport::KeyGenerator) do
        def generate_key(salt, key_size)
          OpenSSL::PKCS5.pbkdf2_hmac(@secret, salt, @iterations, key_size, "SHA1")
        end
      end.new("foo", iterations: 2)
      caching_generator = ActiveSupport::CachingKeyGenerator.new(key_generator)
      ActiveSupport::Ractors.make_shareable(caching_generator)

      key = on_ractor(caching_generator) do |caching_generator|
        caching_generator.generate_key("some_salt", 32)
      end

      assert_equal key, caching_generator.generate_key("some_salt", 32)
    end
  end
end
