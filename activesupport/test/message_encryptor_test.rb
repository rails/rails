require 'abstract_unit'

begin
  require 'openssl'
  OpenSSL::Digest::SHA1
rescue LoadError, NameError
  $stderr.puts "Skipping MessageEncryptor test: broken OpenSSL install"
else

require 'active_support/time'
require 'active_support/json'

class MessageEncryptorTest < ActiveSupport::TestCase
  
  class JSONSerializer
    def dump(value)
      ActiveSupport::JSON.encode(value)
    end
    
    def load(value)
      ActiveSupport::JSON.decode(value)
    end
  end
  
  def setup
    @encryptor = ActiveSupport::MessageEncryptor.new(SecureRandom.hex(64))
    @data = { :some => "data", :now => Time.local(2010) }
  end

  def test_simple_round_tripping
    message = @encryptor.encrypt(@data)
    assert_equal @data, @encryptor.decrypt(message)
  end

  def test_encrypting_twice_yields_differing_cipher_text
    first_messqage = @encryptor.encrypt(@data)
    second_message = @encryptor.encrypt(@data)
    assert_not_equal first_messqage, second_message
  end

  def test_messing_with_either_value_causes_failure
    text, iv = @encryptor.encrypt(@data).split("--")
    assert_not_decrypted([iv, text] * "--")
    assert_not_decrypted([text, munge(iv)] * "--")
    assert_not_decrypted([munge(text), iv] * "--")
    assert_not_decrypted([munge(text), munge(iv)] * "--")
  end

  def test_signed_round_tripping
    message = @encryptor.encrypt_and_sign(@data)
    assert_equal @data, @encryptor.decrypt_and_verify(message)
  end
  
  def test_alternative_serialization_method
    encryptor = ActiveSupport::MessageEncryptor.new(SecureRandom.hex(64), :serializer => JSONSerializer.new)
    message = encryptor.encrypt_and_sign({ :foo => 123, 'bar' => Time.utc(2010) })
    assert_equal encryptor.decrypt_and_verify(message), { "foo" => 123, "bar" => "2010-01-01T00:00:00Z" }
  end

  def test_digest_algorithm_as_second_parameter_deprecation
    assert_deprecated(/options hash/) do
      ActiveSupport::MessageEncryptor.new(SecureRandom.hex(64), 'aes-256-cbc')
    end
  end
  
  private
    def assert_not_decrypted(value)
      assert_raise(ActiveSupport::MessageEncryptor::InvalidMessage) do
        @encryptor.decrypt(value)
      end
    end

    def munge(base64_string)
      bits = ActiveSupport::Base64.decode64(base64_string)
      bits.reverse!
      ActiveSupport::Base64.encode64s(bits)
    end
end

end
