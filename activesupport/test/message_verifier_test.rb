# frozen_string_literal: true

require "abstract_unit"
require "openssl"
require "active_support/time"
require "active_support/json"
require_relative "metadata/shared_metadata_tests"

class MessageVerifierTest < ActiveSupport::TestCase
  class JSONSerializer
    def dump(value)
      ActiveSupport::JSON.encode(value)
    end

    def load(value)
      ActiveSupport::JSON.decode(value)
    end
  end

  def setup
    @verifier = ActiveSupport::MessageVerifier.new("Hey, I'm a secret!")
    @data = { some: "data", now: Time.utc(2010) }
    @secret = SecureRandom.random_bytes(32)
  end

  def test_valid_message
    data, hash = @verifier.generate(@data).split("--")
    assert !@verifier.valid_message?(nil)
    assert !@verifier.valid_message?("")
    assert !@verifier.valid_message?("\xff") # invalid encoding
    assert !@verifier.valid_message?("#{data.reverse}--#{hash}")
    assert !@verifier.valid_message?("#{data}--#{hash.reverse}")
    assert !@verifier.valid_message?("purejunk")
  end

  def test_simple_round_tripping
    message = @verifier.generate(@data)
    assert_equal @data, @verifier.verified(message)
    assert_equal @data, @verifier.verify(message)
  end

  def test_verified_returns_false_on_invalid_message
    assert !@verifier.verified("purejunk")
  end

  def test_verify_exception_on_invalid_message
    assert_raise(ActiveSupport::MessageVerifier::InvalidSignature) do
      @verifier.verify("purejunk")
    end
  end

  def test_alternative_serialization_method
    prev = ActiveSupport.use_standard_json_time_format
    ActiveSupport.use_standard_json_time_format = true
    verifier = ActiveSupport::MessageVerifier.new("Hey, I'm a secret!", serializer: JSONSerializer.new)
    message = verifier.generate(:foo => 123, "bar" => Time.utc(2010))
    exp = { "foo" => 123, "bar" => "2010-01-01T00:00:00.000Z" }
    assert_equal exp, verifier.verified(message)
    assert_equal exp, verifier.verify(message)
  ensure
    ActiveSupport.use_standard_json_time_format = prev
  end

  def test_raise_error_when_argument_class_is_not_loaded
    # To generate the valid message below:
    #
    #   AutoloadClass = Struct.new(:foo)
    #   valid_message = @verifier.generate(foo: AutoloadClass.new('foo'))
    #
    valid_message = "BAh7BjoIZm9vbzonTWVzc2FnZVZlcmlmaWVyVGVzdDo6QXV0b2xvYWRDbGFzcwY6CUBmb29JIghmb28GOgZFVA==--f3ef39a5241c365083770566dc7a9eb5d6ace914"
    exception = assert_raise(ArgumentError, NameError) do
      @verifier.verified(valid_message)
    end
    assert_includes ["uninitialized constant MessageVerifierTest::AutoloadClass",
                    "undefined class/module MessageVerifierTest::AutoloadClass"], exception.message
    exception = assert_raise(ArgumentError, NameError) do
      @verifier.verify(valid_message)
    end
    assert_includes ["uninitialized constant MessageVerifierTest::AutoloadClass",
                    "undefined class/module MessageVerifierTest::AutoloadClass"], exception.message
  end

  def test_raise_error_when_secret_is_nil
    exception = assert_raise(ArgumentError) do
      ActiveSupport::MessageVerifier.new(nil)
    end
    assert_equal "Secret should not be nil.", exception.message
  end

  def test_backward_compatibility_messages_signed_without_metadata
    signed_message = "BAh7BzoJc29tZUkiCWRhdGEGOgZFVDoIbm93SXU6CVRpbWUNIIAbgAAAAAAHOgtvZmZzZXRpADoJem9uZUkiCFVUQwY7BkY=--d03c52c91dfe4ccc5159417c660461bcce005e96"
    assert_equal @data, @verifier.verify(signed_message)
  end

  def test_with_rotated_raw_key
    old_raw_key = SecureRandom.random_bytes(32)

    old_verifier = ActiveSupport::MessageVerifier.new(old_raw_key, digest: "SHA1")
    old_message = old_verifier.generate("message verified with old raw key")

    verifier = ActiveSupport::MessageVerifier.new(@secret, digest: "SHA1")
    verifier.rotate raw_key: old_raw_key, digest: "SHA1"

    assert_equal "message verified with old raw key", verifier.verified(old_message)
  end

  def test_with_rotated_secret_and_salt
    old_secret, old_salt = SecureRandom.random_bytes(32), "old salt"

    old_raw_key = ActiveSupport::KeyGenerator.new(old_secret, iterations: 1000).generate_key(old_salt)
    old_verifier = ActiveSupport::MessageVerifier.new(old_raw_key, digest: "SHA1")
    old_message = old_verifier.generate("message verified with old secret and salt")

    verifier = ActiveSupport::MessageVerifier.new(@secret, digest: "SHA1")
    verifier.rotate secret: old_secret, salt: old_salt, digest: "SHA1"

    assert_equal "message verified with old secret and salt", verifier.verified(old_message)
  end

  def test_with_rotated_key_generator
    old_key_gen, old_salt = ActiveSupport::KeyGenerator.new(SecureRandom.random_bytes(32), iterations: 256), "old salt"

    old_raw_key = old_key_gen.generate_key(old_salt)
    old_verifier = ActiveSupport::MessageVerifier.new(old_raw_key, digest: "SHA1")
    old_message = old_verifier.generate("message verified with old key generator and salt")

    verifier = ActiveSupport::MessageVerifier.new(@secret, digest: "SHA1")
    verifier.rotate key_generator: old_key_gen, salt: old_salt, digest: "SHA1"

    assert_equal "message verified with old key generator and salt", verifier.verified(old_message)
  end

  def test_with_rotating_multiple_verifiers
    old_raw_key, older_raw_key = SecureRandom.random_bytes(32), SecureRandom.random_bytes(32)

    old_verifier = ActiveSupport::MessageVerifier.new(old_raw_key, digest: "SHA256")
    old_message = old_verifier.generate("message verified with old raw key")

    older_verifier = ActiveSupport::MessageVerifier.new(older_raw_key, digest: "SHA1")
    older_message = older_verifier.generate("message verified with older raw key")

    verifier = ActiveSupport::MessageVerifier.new("new secret", digest: "SHA512")
    verifier.rotate raw_key: old_raw_key, digest: "SHA256"
    verifier.rotate raw_key: older_raw_key, digest: "SHA1"

    assert_equal "verified message", verifier.verified(verifier.generate("verified message"))
    assert_equal "message verified with old raw key", verifier.verified(old_message)
    assert_equal "message verified with older raw key", verifier.verified(older_message)
  end

  def test_on_rotation_keyword_block_is_called_and_verified_returns_message
    callback_ran, message = nil, nil

    old_raw_key, older_raw_key = SecureRandom.random_bytes(32), SecureRandom.random_bytes(32)

    older_verifier = ActiveSupport::MessageVerifier.new(older_raw_key, digest: "SHA1")
    older_message = older_verifier.generate(encoded: "message")

    verifier = ActiveSupport::MessageVerifier.new("new secret", digest: "SHA512")
    verifier.rotate raw_key: old_raw_key, digest: "SHA256"
    verifier.rotate raw_key: older_raw_key, digest: "SHA1"

    message = verifier.verified(older_message, on_rotation: proc { callback_ran = true })

    assert callback_ran, "callback was ran"
    assert_equal({ encoded: "message" }, message)
  end

  def test_with_rotated_metadata
    old_secret, old_salt = SecureRandom.random_bytes(32), "old salt"

    old_raw_key = ActiveSupport::KeyGenerator.new(old_secret, iterations: 1000).generate_key(old_salt)
    old_verifier = ActiveSupport::MessageVerifier.new(old_raw_key, digest: "SHA1")
    old_message = old_verifier.generate(
      "message verified with old secret, salt, and metadata", purpose: "rotation")

    verifier = ActiveSupport::MessageVerifier.new(@secret, digest: "SHA1")
    verifier.rotate secret: old_secret, salt: old_salt, digest: "SHA1"

    assert_equal "message verified with old secret, salt, and metadata",
      verifier.verified(old_message, purpose: "rotation")
  end
end

class MessageVerifierMetadataTest < ActiveSupport::TestCase
  include SharedMessageMetadataTests

  setup do
    @verifier = ActiveSupport::MessageVerifier.new("Hey, I'm a secret!", verifier_options)
  end

  def test_verify_raises_when_purpose_differs
    assert_raise(ActiveSupport::MessageVerifier::InvalidSignature) do
      @verifier.verify(generate(data, purpose: "payment"), purpose: "shipping")
    end
  end

  def test_verify_raises_when_expired
    signed_message = generate(data, expires_in: 1.month)

    travel 2.months
    assert_raise(ActiveSupport::MessageVerifier::InvalidSignature) do
      @verifier.verify(signed_message)
    end
  end

  private
    def generate(message, **options)
      @verifier.generate(message, options)
    end

    def parse(message, **options)
      @verifier.verified(message, options)
    end

    def verifier_options
      Hash.new
    end
end

class MessageVerifierMetadataMarshalTest < MessageVerifierMetadataTest
  private
    def verifier_options
      { serializer: Marshal }
    end
end

class MessageVerifierMetadataJSONTest < MessageVerifierMetadataTest
  private
    def verifier_options
      { serializer: MessageVerifierTest::JSONSerializer.new }
    end
end

class MessageEncryptorMetadataNullSerializerTest < MessageVerifierMetadataTest
  private
    def data
      "string message"
    end

    def null_serializing?
      true
    end

    def verifier_options
      { serializer: ActiveSupport::MessageEncryptor::NullSerializer }
    end
end
