require 'abstract_unit'
require 'openssl'
require 'active_support/time'
require 'active_support/json'
require 'active_support/core_ext/securerandom'

module CommonModule
  def munge(base64_string)
    bits = decode(base64_string)
    bits.reverse!
    encode(bits)
  end
end

class MessageEncryptorTest < ActiveSupport::TestCase
  include CommonModule

  class JSONSerializer
    def dump(value)
      ActiveSupport::JSON.encode(value)
    end

    def load(value)
      ActiveSupport::JSON.decode(value)
    end
  end

  def setup
    @secret = SecureRandom.hex(32)
    @encryptor = new_encryptor
    @payload = 'data'
    @options = { expires_at: Time.local(2022), for: 'test' }
  end

  def test_simple_round_tripping
    message = @encryptor.encrypt_and_sign(@payload, @options)
    assert_equal @payload, @encryptor.decrypt_and_verify(message, for: 'test')
    encryptor = new_encryptor(enc: 'A256GCM')
    message = encryptor.encrypt_and_sign(@payload, @options)
    assert_equal @payload, encryptor.decrypt_and_verify(message, for: 'test')
    encryptor = new_encryptor(enc: 'A128GCM')
    message = encryptor.encrypt_and_sign(@payload, @options)
    assert_equal @payload, encryptor.decrypt_and_verify(message, for: 'test')
    encryptor = new_encryptor(enc: 'A128CBC-HS256')
    message = encryptor.encrypt_and_sign(@payload, @options)
    assert_equal @payload, encryptor.decrypt_and_verify(message, for: 'test')
    encryptor = new_encryptor(cipher: 'aes-128-cbc')
    message = encryptor.encrypt_and_sign(@payload, @options)
    assert_equal @payload, encryptor.decrypt_and_verify(message, for: 'test')
  end

  def test_error_when_unexpected_algorithm_is_used
    assert_unexpected_algorithm(enc: 'A192GCM')
    assert_unexpected_algorithm(alg: 'ECDH-ES')
    assert_unexpected_algorithm(cipher: 'aes-128-ctr')
  end

  def test_raise_for_invalid_messages
    h, key, iv, ciphtxt, tag = @encryptor.encrypt_and_sign(@payload, @options).split('.')
    assert_not_decrypted 'this.is.invalid.test.message'
    assert_not_decrypted '....'
    assert_not_decrypted "#{h.reverse}.#{key}.#{iv}.#{ciphtxt}.#{tag}"
    assert_not_decrypted "#{h}.#{key}.#{iv.reverse}.#{ciphtxt}.#{tag}"
    assert_not_decrypted "#{h}.#{key}.#{iv}.#{ciphtxt.reverse}.#{tag}"
    assert_not_decrypted "#{h}.#{key}.#{iv}.#{ciphtxt}.#{tag.reverse}"
  end

  def test_error_when_message_is_in_invalid_format
    assert_invalid_format ''
    assert_invalid_format 'pure.junk.data.in.this.string'
    assert_invalid_format '.........'
  end

  def test_messing_with_message_causes_failure
    h, key, iv, ciphtxt, tag = @encryptor.encrypt_and_sign(@payload, @options).split('.')
    assert_not_decrypted "#{munge(h)}.#{key}.#{iv}.#{ciphtxt}.#{tag}"
    assert_not_decrypted "#{h}.#{key}.#{iv}.#{ciphtxt}.#{munge(tag)}"
    assert_not_decrypted "#{h}.#{key}.#{munge(iv)}.#{ciphtxt}.#{tag}"
    assert_not_decrypted "#{h}.#{key}.#{iv}.#{munge(ciphtxt)}.#{tag}"
  end

  def test_decrypt_legacy_message
    data = { foo: 'data', bar: Time.local(2022) }
    legacy_encryptor = ActiveSupport::LegacyMessageEncryptor.new(@secret)
    assert_equal data, @encryptor.decrypt_and_verify(legacy_encryptor.encrypt_and_sign(data))
  end

  def test_encrypting_twice_yields_differing_cipher_text
    first_message = @encryptor.encrypt_and_sign(@payload, @options).split('.')[3]
    second_message = @encryptor.encrypt_and_sign(@payload, @options).split('.')[3]
    assert_not_equal first_message, second_message
  end

  def test_raises_on_invalid_purpose
    message = @encryptor.encrypt_and_sign(@payload, @options)
    assert_raise(ActiveSupport::Claims::InvalidClaims) do
      @encryptor.decrypt_and_verify(message, for: 'different_purpose')
    end
  end

  def test_raises_on_message_expiry
    expired_message = @encryptor.encrypt_and_sign(@payload, expires_at: Time.local(2010), for: 'test')
    assert_raise(ActiveSupport::Claims::ExpiredClaims) do
      @encryptor.decrypt_and_verify(expired_message, for: 'test')
    end
  end

  def test_alternative_serialization_method
    prev = ActiveSupport.use_standard_json_time_format
    ActiveSupport.use_standard_json_time_format = true
    encryptor = ActiveSupport::MessageEncryptor.new(SecureRandom.hex(32), SecureRandom.hex(32), serializer: JSONSerializer.new)
    message = encryptor.encrypt_and_sign(@payload, @options)
    assert_equal @payload, encryptor.decrypt_and_verify(message, for: 'test')
  ensure
    ActiveSupport.use_standard_json_time_format = prev
  end

  private
    def new_encryptor(**options)
      ActiveSupport::MessageEncryptor.new(@secret, **options)
    end

    def assert_not_decrypted(value)
      assert_raise(ActiveSupport::MessageEncryptor::InvalidMessage) do
        @encryptor.decrypt_and_verify(value, for: 'test')
      end
    end

    def assert_invalid_format(value)
      assert_raise(ActiveSupport::MessageEncryptor::MalformedToken) do
        @encryptor.decrypt_and_verify(value, for: 'test')
      end
    end

    def assert_unexpected_algorithm(**options)
      assert_raise(ActiveSupport::MessageEncryptor::UnexpectedAlgorithm) do
        new_encryptor(**options)
      end
    end

    def encode(value)
      Base64.urlsafe_encode64 value
    end

    def decode(value)
      return if value.nil?
      Base64.urlsafe_decode64 value
    end
end

class LegacyMessageEncryptorTest < ActiveSupport::TestCase
  include CommonModule

  class JSONSerializer
    def dump(value)
      ActiveSupport::JSON.encode(value)
    end

    def load(value)
      ActiveSupport::JSON.decode(value)
    end
  end

  def setup
    @secret    = SecureRandom.hex(32)
    @verifier  = ActiveSupport::LegacyMessageVerifier.new(@secret, :serializer => ActiveSupport::MessageEncryptor::NullSerializer)
    @encryptor = ActiveSupport::LegacyMessageEncryptor.new(@secret)
    @data = { :some => "data", :now => Time.local(2010) }
  end

  def test_encrypting_twice_yields_differing_cipher_text
    first_message = @encryptor.encrypt_and_sign(@data).split('--').first
    second_message = @encryptor.encrypt_and_sign(@data).split('--').first
    assert_not_equal first_message, second_message
  end

  def test_messing_with_either_encrypted_values_causes_failure
    text, iv = @verifier.verify(@encryptor.encrypt_and_sign(@data)).split('--')
    assert_not_decrypted [iv, text].join('--')
    assert_not_decrypted [text, munge(iv)].join('--')
    assert_not_decrypted [munge(text), iv].join('--')
    assert_not_decrypted [munge(text), munge(iv)].join('--')
  end

  def test_messing_with_verified_values_causes_failures
    text, iv = @encryptor.encrypt_and_sign(@data).split('--')
    assert_not_verified [iv, text].join('--')
    assert_not_verified [text, munge(iv)].join('--')
    assert_not_verified [munge(text), iv].join('--')
    assert_not_verified [munge(text), munge(iv)].join('--')
  end

  def test_signed_round_tripping
    message = @encryptor.encrypt_and_sign(@data)
    assert_equal @data, @encryptor.decrypt_and_verify(message)
  end

  def test_alternative_serialization_method
    prev = ActiveSupport.use_standard_json_time_format
    ActiveSupport.use_standard_json_time_format = true
    encryptor = ActiveSupport::LegacyMessageEncryptor.new(SecureRandom.hex(32), SecureRandom.hex(32), :serializer => JSONSerializer.new)
    message = encryptor.encrypt_and_sign({ :foo => 123, 'bar' => Time.utc(2010) })
    exp = { "foo" => 123, "bar" => "2010-01-01T00:00:00.000Z" }
    assert_equal exp, encryptor.decrypt_and_verify(message)
  ensure
    ActiveSupport.use_standard_json_time_format = prev
  end

  def test_message_obeys_strict_encoding
    bad_encoding_characters = "\n!@#"
    message, iv = @verifier.verify(@encryptor.encrypt_and_sign("This is a very \n\nhumble string" + bad_encoding_characters)).split('--')

    assert_not_decrypted("#{::Base64.encode64 message.to_s}--#{::Base64.encode64 iv.to_s}")
    assert_not_verified("#{::Base64.encode64 message.to_s}--#{::Base64.encode64 iv.to_s}")

    assert_not_decrypted([iv,  message] * bad_encoding_characters)
    assert_not_verified([iv,  message] * bad_encoding_characters)
  end

  private
    def assert_not_decrypted(value)
      assert_raise(ActiveSupport::LegacyMessageEncryptor::InvalidMessage) do
        @encryptor.decrypt_and_verify(@verifier.generate(value))
      end
    end

    def assert_not_verified(value)
      assert_raise(ActiveSupport::LegacyMessageVerifier::InvalidSignature) do
        @encryptor.decrypt_and_verify(value)
      end
    end

    def decode(value)
      ::Base64.strict_decode64(value)
    end

    def encode(value)
      ::Base64.strict_encode64(value)
    end
end
