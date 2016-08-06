require "abstract_unit"

begin
  require "openssl"
  OpenSSL::PKCS5
rescue LoadError, NameError
  $stderr.puts "Skipping KeyGenerator test: broken OpenSSL install"
else

require "active_support/time"
require "active_support/json"

class KeyGeneratorTest < ActiveSupport::TestCase
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
    assert_equal expected, ActiveSupport::KeyGenerator.new("0" * 64).generate_key("some_salt").unpack("H*").first

    expected = "b129376f68f1ecae788d7433310249d65ceec090ecacd4c872a3a9e9ec78e055"
    assert_equal expected, ActiveSupport::KeyGenerator.new("0" * 64).generate_key("some_salt", 32).unpack("H*").first

    expected = "cbea7f7f47df705967dc508f4e446fd99e7797b1d70011c6899cd39bbe62907b8508337d678505a7dc8184e037f1003ba3d19fc5d829454668e91d2518692eae"
    assert_equal expected, ActiveSupport::KeyGenerator.new("0" * 64, iterations: 2).generate_key("some_salt").unpack("H*").first
  end
end

class CachingKeyGeneratorTest < ActiveSupport::TestCase
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
end

end
