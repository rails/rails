require 'abstract_unit'
require 'openssl'
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
    @secret    = SecureRandom.random_bytes(32)
    @verifier  = ActiveSupport::MessageVerifier.new(@secret, :serializer => ActiveSupport::MessageEncryptor::NullSerializer)
    @encryptor = ActiveSupport::MessageEncryptor.new(@secret)
    @data = { :some => "data", :now => Time.local(2010) }
  end

  def test_encrypting_twice_yields_differing_cipher_text
    first_message = @encryptor.encrypt_and_sign(@data).split("--").first
    second_message = @encryptor.encrypt_and_sign(@data).split("--").first
    assert_not_equal first_message, second_message
  end

  def test_messing_with_either_encrypted_values_causes_failure
    text, iv = @verifier.verify(@encryptor.encrypt_and_sign(@data)).split("--")
    assert_not_decrypted([iv, text] * "--")
    assert_not_decrypted([text, munge(iv)] * "--")
    assert_not_decrypted([munge(text), iv] * "--")
    assert_not_decrypted([munge(text), munge(iv)] * "--")
  end

  def test_messing_with_verified_values_causes_failures
    text, iv = @encryptor.encrypt_and_sign(@data).split("--")
    assert_not_verified([iv, text] * "--")
    assert_not_verified([text, munge(iv)] * "--")
    assert_not_verified([munge(text), iv] * "--")
    assert_not_verified([munge(text), munge(iv)] * "--")
  end

  def test_signed_round_tripping
    message = @encryptor.encrypt_and_sign(@data)
    assert_equal @data, @encryptor.decrypt_and_verify(message)
  end

  def test_alternative_serialization_method
    prev = ActiveSupport.use_standard_json_time_format
    ActiveSupport.use_standard_json_time_format = true
    encryptor = ActiveSupport::MessageEncryptor.new(SecureRandom.random_bytes(32), SecureRandom.random_bytes(128), :serializer => JSONSerializer.new)
    message = encryptor.encrypt_and_sign({ :foo => 123, 'bar' => Time.utc(2010) })
    exp = { "foo" => 123, "bar" => "2010-01-01T00:00:00.000Z" }
    assert_equal exp, encryptor.decrypt_and_verify(message)
  ensure
    ActiveSupport.use_standard_json_time_format = prev
  end

  def test_message_obeys_strict_encoding
    bad_encoding_characters = "\n!@#"
    message, iv = @encryptor.encrypt_and_sign("This is a very \n\nhumble string"+bad_encoding_characters)

    assert_not_decrypted("#{::Base64.encode64 message.to_s}--#{::Base64.encode64 iv.to_s}")
    assert_not_verified("#{::Base64.encode64 message.to_s}--#{::Base64.encode64 iv.to_s}")

    assert_not_decrypted([iv,  message] * bad_encoding_characters)
    assert_not_verified([iv,  message] * bad_encoding_characters)
  end

  private

  def assert_not_decrypted(value)
    assert_raise(ActiveSupport::MessageEncryptor::InvalidMessage) do
      @encryptor.decrypt_and_verify(@verifier.generate(value))
    end
  end

  def assert_not_verified(value)
    assert_raise(ActiveSupport::MessageVerifier::InvalidSignature) do
      @encryptor.decrypt_and_verify(value)
    end
  end

  def munge(base64_string)
    bits = ::Base64.strict_decode64(base64_string)
    bits.reverse!
    ::Base64.strict_encode64(bits)
  end
end
