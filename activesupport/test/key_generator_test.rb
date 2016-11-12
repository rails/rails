require 'abstract_unit'

begin
  require 'openssl'
  OpenSSL::PKCS5
rescue LoadError, NameError
  $stderr.puts "Skipping KeyGenerator test: broken OpenSSL install"
else

require 'active_support/time'
require 'active_support/json'

class KeyGeneratorTest < ActiveSupport::TestCase
  def setup
    @secret    = SecureRandom.hex(64)
    @generator = ActiveSupport::KeyGenerator.new(@secret, :iterations=>2)
  end

  test "Generating a key of the default length" do
    derived_key = @generator.generate_key("some_salt")
    assert_kind_of String, derived_key
    assert_equal OpenSSL::Cipher.new('aes-256-cbc').key_len, derived_key.length, "Should have generated a key of the default size"
  end

  test "Generating a key of an alternative length" do
    derived_key = @generator.generate_key("some_salt", 32)
    assert_kind_of String, derived_key
    assert_equal 32, derived_key.length, "Should have generated a key of the right size"
  end
end

class CachingKeyGeneratorTest < ActiveSupport::TestCase
  def setup
    @secret    = SecureRandom.hex(64)
    @generator = ActiveSupport::KeyGenerator.new(@secret, :iterations=>2)
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
end

end
