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
    assert_equal OpenSSL::Digest::SHA1.new.block_length, derived_key.length, "Should have generated a key of the default size"
  end

  test "Generating a key of an alternative length" do
    derived_key = @generator.generate_key("some_salt", 32)
    assert_kind_of String, derived_key
    assert_equal 32, derived_key.length, "Should have generated a key of the right size"
  end
end

end
