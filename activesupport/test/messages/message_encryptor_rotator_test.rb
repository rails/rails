# frozen_string_literal: true

require_relative "../abstract_unit"
require_relative "message_rotator_tests"

class MessageEncryptorRotatorTest < ActiveSupport::TestCase
  include MessageRotatorTests

  test "rotate cipher" do
    assert_rotate [cipher: "aes-256-gcm"], [cipher: "aes-256-cbc"]
  end

  test "rotate verifier secret when using non-authenticated encryption" do
    with_authenticated_encryption(false) do
      assert_rotate \
        [secret("encryption"), secret("new verifier")],
        [secret("encryption"), secret("old verifier")],
        [secret("encryption"), secret("older verifier")]
    end
  end

  test "rotate verifier digest when using non-authenticated encryption" do
    with_authenticated_encryption(false) do
      assert_rotate [digest: "SHA256"], [digest: "SHA1"], [digest: "MD5"]
    end
  end

  private
    def secret(key)
      @secrets ||= {}
      @secrets[key] ||= SecureRandom.random_bytes(32)
    end

    def make_codec(secret = secret("secret"), verifier_secret = nil, **options)
      ActiveSupport::MessageEncryptor.new(secret, verifier_secret, **options)
    end

    def encode(data, encryptor, **options)
      encryptor.encrypt_and_sign(data, **options)
    end

    def decode(message, encryptor, **options)
      encryptor.decrypt_and_verify(message, **options)
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      nil
    end

    def with_authenticated_encryption(value = true)
      original_value = ActiveSupport::MessageEncryptor.use_authenticated_message_encryption
      ActiveSupport::MessageEncryptor.use_authenticated_message_encryption = value
      yield
    ensure
      ActiveSupport::MessageEncryptor.use_authenticated_message_encryption = original_value
    end
end
