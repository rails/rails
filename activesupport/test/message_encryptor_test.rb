# frozen_string_literal: true

require "abstract_unit"
require "openssl"
require "active_support/time"
require "active_support/json"
require_relative "metadata/shared_metadata_tests"

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
    @verifier  = ActiveSupport::MessageVerifier.new(@secret, serializer: ActiveSupport::MessageEncryptor::NullSerializer)
    @encryptor = ActiveSupport::MessageEncryptor.new(@secret)
    @data = { some: "data", now: Time.local(2010) }
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

  def test_backwards_compat_for_64_bytes_key
    # 64 bit key
    secret = ["3942b1bf81e622559ed509e3ff274a780784fe9e75b065866bd270438c74da822219de3156473cc27df1fd590e4baf68c95eeb537b6e4d4c5a10f41635b5597e"].pack("H*")
    # Encryptor with 32 bit key, 64 bit secret for verifier
    encryptor = ActiveSupport::MessageEncryptor.new(secret[0..31], secret)
    # Message generated with 64 bit key
    message = "eHdGeExnZEwvMSt3U3dKaFl1WFo0TjVvYzA0eGpjbm5WSkt5MXlsNzhpZ0ZnbWhBWFlQZTRwaXE1bVJCS2oxMDZhYVp2dVN3V0lNZUlWQ3c2eVhQbnhnVjFmeVVubmhRKzF3WnZyWHVNMDg9LS1HSisyakJVSFlPb05ISzRMaXRzcFdBPT0=--831a1d54a3cda8a0658dc668a03dedcbce13b5ca"
    assert_equal "data", encryptor.decrypt_and_verify(message)[:some]
  end

  def test_alternative_serialization_method
    prev = ActiveSupport.use_standard_json_time_format
    ActiveSupport.use_standard_json_time_format = true
    encryptor = ActiveSupport::MessageEncryptor.new(SecureRandom.random_bytes(32), SecureRandom.random_bytes(128), serializer: JSONSerializer.new)
    message = encryptor.encrypt_and_sign(:foo => 123, "bar" => Time.utc(2010))
    exp = { "foo" => 123, "bar" => "2010-01-01T00:00:00.000Z" }
    assert_equal exp, encryptor.decrypt_and_verify(message)
  ensure
    ActiveSupport.use_standard_json_time_format = prev
  end

  def test_message_obeys_strict_encoding
    bad_encoding_characters = "\n!@#"
    message, iv = @encryptor.encrypt_and_sign("This is a very \n\nhumble string" + bad_encoding_characters)

    assert_not_decrypted("#{::Base64.encode64 message.to_s}--#{::Base64.encode64 iv.to_s}")
    assert_not_verified("#{::Base64.encode64 message.to_s}--#{::Base64.encode64 iv.to_s}")

    assert_not_decrypted([iv,  message] * bad_encoding_characters)
    assert_not_verified([iv,  message] * bad_encoding_characters)
  end

  def test_aead_mode_encryption
    encryptor = ActiveSupport::MessageEncryptor.new(@secret, cipher: "aes-256-gcm")
    message = encryptor.encrypt_and_sign(@data)
    assert_equal @data, encryptor.decrypt_and_verify(message)
  end

  def test_aead_mode_with_hmac_cbc_cipher_text
    encryptor = ActiveSupport::MessageEncryptor.new(@secret, cipher: "aes-256-gcm")

    assert_aead_not_decrypted(encryptor, "eHdGeExnZEwvMSt3U3dKaFl1WFo0TjVvYzA0eGpjbm5WSkt5MXlsNzhpZ0ZnbWhBWFlQZTRwaXE1bVJCS2oxMDZhYVp2dVN3V0lNZUlWQ3c2eVhQbnhnVjFmeVVubmhRKzF3WnZyWHVNMDg9LS1HSisyakJVSFlPb05ISzRMaXRzcFdBPT0=--831a1d54a3cda8a0658dc668a03dedcbce13b5ca")
  end

  def test_messing_with_aead_values_causes_failures
    encryptor = ActiveSupport::MessageEncryptor.new(@secret, cipher: "aes-256-gcm")
    text, iv, auth_tag = encryptor.encrypt_and_sign(@data).split("--")
    assert_aead_not_decrypted(encryptor, [iv, text, auth_tag] * "--")
    assert_aead_not_decrypted(encryptor, [munge(text), iv, auth_tag] * "--")
    assert_aead_not_decrypted(encryptor, [text, munge(iv), auth_tag] * "--")
    assert_aead_not_decrypted(encryptor, [text, iv, munge(auth_tag)] * "--")
    assert_aead_not_decrypted(encryptor, [munge(text), munge(iv), munge(auth_tag)] * "--")
    assert_aead_not_decrypted(encryptor, [text, iv] * "--")
    assert_aead_not_decrypted(encryptor, [text, iv, auth_tag[0..-2]] * "--")
  end

  def test_backwards_compatibility_decrypt_previously_encrypted_messages_without_metadata
    secret = "\xB7\xF0\xBCW\xB1\x18`\xAB\xF0\x81\x10\xA4$\xF44\xEC\xA1\xDC\xC1\xDDD\xAF\xA9\xB8\x14\xCD\x18\x9A\x99 \x80)"
    encryptor = ActiveSupport::MessageEncryptor.new(secret, cipher: "aes-256-gcm")
    encrypted_message = "9cVnFs2O3lL9SPvIJuxBOLS51nDiBMw=--YNI5HAfHEmZ7VDpl--ddFJ6tXA0iH+XGcCgMINYQ=="

    assert_equal "Ruby on Rails", encryptor.decrypt_and_verify(encrypted_message)
  end

  def test_rotating_secret
    old_message = ActiveSupport::MessageEncryptor.new(secrets[:old], cipher: "aes-256-gcm").encrypt_and_sign("old")

    encryptor = ActiveSupport::MessageEncryptor.new(@secret, cipher: "aes-256-gcm")
    encryptor.rotate secrets[:old]

    assert_equal "old", encryptor.decrypt_and_verify(old_message)
  end

  def test_rotating_serializer
    old_message = ActiveSupport::MessageEncryptor.new(secrets[:old], cipher: "aes-256-gcm", serializer: JSON).
      encrypt_and_sign(ahoy: :hoy)

    encryptor = ActiveSupport::MessageEncryptor.new(@secret, cipher: "aes-256-gcm", serializer: JSON)
    encryptor.rotate secrets[:old]

    assert_equal({ "ahoy" => "hoy" }, encryptor.decrypt_and_verify(old_message))
  end

  def test_rotating_aes_cbc_secrets
    old_encryptor = ActiveSupport::MessageEncryptor.new(secrets[:old], "old sign", cipher: "aes-256-cbc")
    old_message = old_encryptor.encrypt_and_sign("old")

    encryptor = ActiveSupport::MessageEncryptor.new(@secret)
    encryptor.rotate secrets[:old], "old sign", cipher: "aes-256-cbc"

    assert_equal "old", encryptor.decrypt_and_verify(old_message)
  end

  def test_multiple_rotations
    older_message = ActiveSupport::MessageEncryptor.new(secrets[:older], "older sign").encrypt_and_sign("older")
    old_message = ActiveSupport::MessageEncryptor.new(secrets[:old], "old sign").encrypt_and_sign("old")

    encryptor = ActiveSupport::MessageEncryptor.new(@secret)
    encryptor.rotate secrets[:old], "old sign"
    encryptor.rotate secrets[:older], "older sign"

    assert_equal "new",   encryptor.decrypt_and_verify(encryptor.encrypt_and_sign("new"))
    assert_equal "old",   encryptor.decrypt_and_verify(old_message)
    assert_equal "older", encryptor.decrypt_and_verify(older_message)
  end

  def test_on_rotation_is_called_and_returns_modified_messages
    older_message = ActiveSupport::MessageEncryptor.new(secrets[:older], "older sign").encrypt_and_sign(encoded: "message")

    encryptor = ActiveSupport::MessageEncryptor.new(@secret)
    encryptor.rotate secrets[:old]
    encryptor.rotate secrets[:older], "older sign"

    rotated = false
    message = encryptor.decrypt_and_verify(older_message, on_rotation: proc { rotated = true })

    assert_equal({ encoded: "message" }, message)
    assert rotated
  end

  def test_with_rotated_metadata
    old_message = ActiveSupport::MessageEncryptor.new(secrets[:old], cipher: "aes-256-gcm").
      encrypt_and_sign("metadata", purpose: :rotation)

    encryptor = ActiveSupport::MessageEncryptor.new(@secret, cipher: "aes-256-gcm")
    encryptor.rotate secrets[:old]

    assert_equal "metadata", encryptor.decrypt_and_verify(old_message, purpose: :rotation)
  end

  private
    def assert_aead_not_decrypted(encryptor, value)
      assert_raise(ActiveSupport::MessageEncryptor::InvalidMessage) do
        encryptor.decrypt_and_verify(value)
      end
    end

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

    def secrets
      @secrets ||= Hash.new { |h, k| h[k] = SecureRandom.random_bytes(32) }
    end

    def munge(base64_string)
      bits = ::Base64.strict_decode64(base64_string)
      bits.reverse!
      ::Base64.strict_encode64(bits)
    end
end

class MessageEncryptorMetadataTest < ActiveSupport::TestCase
  include SharedMessageMetadataTests

  setup do
    @secret    = SecureRandom.random_bytes(32)
    @encryptor = ActiveSupport::MessageEncryptor.new(@secret, encryptor_options)
  end

  private
    def generate(message, **options)
      @encryptor.encrypt_and_sign(message, options)
    end

    def parse(data, **options)
      @encryptor.decrypt_and_verify(data, options)
    end

    def encryptor_options; end
end

class MessageEncryptorMetadataMarshalTest < MessageEncryptorMetadataTest
  private
    def encryptor_options
      { serializer: Marshal }
    end
end

class MessageEncryptorMetadataJSONTest < MessageEncryptorMetadataTest
  private
    def encryptor_options
      { serializer: MessageEncryptorTest::JSONSerializer.new }
    end
end
