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
end

class MessageVerifierMetadataTest < ActiveSupport::TestCase
  include SharedMessageMetadataTests

  setup do
    @verifier = ActiveSupport::MessageVerifier.new("Hey, I'm a secret!", verifier_options)
  end

  def test_verify_raises_when_purpose_differs
    assert_raise(ActiveSupport::MessageVerifier::InvalidSignature) do
      @verifier.verify(@verifier.generate(@message, purpose: "payment"), purpose: "shipping")
    end
  end

  def test_verify_raises_when_expired
    signed_message = @verifier.generate(@message, expires_in: 1.month)

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
