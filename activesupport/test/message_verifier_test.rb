require 'abstract_unit'
require 'openssl'
require 'active_support/time'
require 'active_support/json'

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
    @secret = "Hey, I'm a secret!"
    @verifier = ActiveSupport::MessageVerifier.new(@secret)
    @payload = 'data'
    @options = { expires_at: Time.local(2022), for: 'test' }
    @claims = ActiveSupport::Claims.new(payload: @payload, **@options)
  end

  def test_valid_message
    header, claims, digest = @verifier.generate(@payload, @options).split(".")
    assert_not @verifier.valid_message?(nil)
    assert_not @verifier.valid_message?("")
    assert_not @verifier.valid_message?("\xff") # invalid encoding
    assert_not @verifier.valid_message?("#{header.reverse}.#{claims}.#{digest}")
    assert_not @verifier.valid_message?("#{header}.#{claims}.#{digest.reverse}")
    assert_not @verifier.valid_message?("#{header}.#{claims.reverse}.#{digest}")
    assert_not @verifier.valid_message?("purejunk")
    assert_not @verifier.valid_message?("..")
    assert_not @verifier.valid_message?("pure.junk.data")
  end

  def test_simple_round_tripping
    message = @verifier.generate(@payload, @options)
    assert_equal @payload, @verifier.verified(message, for: 'test')
    assert_equal @payload, @verifier.verify(message, for: 'test')
  end

  def test_raise_invalid_signature_when_value_is_nil
    message = @verifier.generate(nil)
    assert message
    assert_raise(ActiveSupport::MessageVerifier::InvalidSignature) do
      @verifier.verify(message)
    end
  end

  def test_verify_legacy_message
    data = { foo: 'data', bar: Time.local(2022) }
    legacy_verifier = ActiveSupport::LegacyMessageVerifier.new(@secret)
    assert_equal data, @verifier.verify(legacy_verifier.generate(data))
  end

  def test_verified_returns_nil_on_invalid_message
    assert_not @verifier.verified("purejunk")
  end

  def test_verified_returns_nil_on_invalid_purpose
    assert_not @verifier.verified(@verifier.generate(@options), for: 'different_purpose')
  end

  def test_verified_returns_nil_on_message_expiry
    expired_message = @verifier.generate(@payload, expires_at: Time.local(2010), for: 'test')
    assert_not @verifier.verified(expired_message, for: 'test')
  end

  def test_verify_exception_on_invalid_message
    assert_raise(ActiveSupport::MessageVerifier::InvalidSignature) do
      @verifier.verify("purejunk")
    end
  end

  def test_verify_exception_on_invalid_purpose
    assert_raise(ActiveSupport::Claims::InvalidClaims) do
      @verifier.verify(@verifier.generate(@options), for: 'different_purpose')
    end
  end

  def test_verify_exception_on_message_expiry
    expired_message = @verifier.generate(@payload, expires_at: Time.local(2010), for: 'test')
    assert_raise(ActiveSupport::Claims::ExpiredClaims) do
      @verifier.verify(expired_message, for: 'test')
    end
  end

  def test_alternative_serialization_method
    prev = ActiveSupport.use_standard_json_time_format
    ActiveSupport.use_standard_json_time_format = true
    verifier = ActiveSupport::MessageVerifier.new(@secret, serializer: JSONSerializer.new)
    payload = 123
    options = { expires_at: Time.local(2022), for: 'test' }
    message = verifier.generate(payload, options)
    assert_equal payload, verifier.verified(message, for: 'test')
    assert_equal payload, verifier.verify(message, for: 'test')
  ensure
    ActiveSupport.use_standard_json_time_format = prev
  end

  def test_raise_error_when_argument_class_is_not_loaded
    # To generate the valid message below:
    #
    #   AutoloadClass = Struct.new(:foo)
    #   valid_message = @verifier.generate(foo: AutoloadClass.new('foo'))
    #
    valid_message = "BAh7B0kiCHR5cAY6BkVUSSIISldUBjsAVEkiCGFsZwY7AFRJIglTSEExBjsAVA==.BAh7CDoIcGxkewY6CGZvb1M6J01lc3NhZ2VWZXJpZmllclRlc3Q6OkF1dG9sb2FkQ2xhc3MGOwZJIghmb28GOgZFVDoIZm9ySSIOdW5pdmVyc2FsBjsIVDoIZXhwSSIdMjAxNS0wOC0wOVQxNzo1OToxNi4xMjVaBjsIVA==.MzMwZjlmMDBhYWE1NzNiN2U2MGJlMjM2YWIzYTZiMGI1MjY0YTE1MA=="
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
    assert_equal exception.message, 'Secret should not be nil.'
  end
end

class LegacyMessageVerifierTest < ActiveSupport::TestCase

  class JSONSerializer
    def dump(value)
      ActiveSupport::JSON.encode(value)
    end

    def load(value)
      ActiveSupport::JSON.decode(value)
    end
  end

  def setup
    @verifier = ActiveSupport::LegacyMessageVerifier.new("Hey, I'm a secret!")
    @data = { :some => "data", :now => Time.local(2010) }
  end

  def test_valid_message
    data, hash = @verifier.generate(@data).split("--")
    assert_not @verifier.valid_message?(nil)
    assert_not @verifier.valid_message?("")
    assert_not @verifier.valid_message?("#{data.reverse}--#{hash}")
    assert_not @verifier.valid_message?("#{data}--#{hash.reverse}")
    assert_not @verifier.valid_message?("--dsa--")
  end

  def test_simple_round_tripping
    message = @verifier.generate(@data)
    assert_equal @data, @verifier.verified(message)
    assert_equal @data, @verifier.verify(message)
  end

  def test_verified_returns_false_on_invalid_message
    assert_not @verifier.verified("purejunk")
  end

  def test_verify_exception_on_invalid_message
    assert_raise(ActiveSupport::LegacyMessageVerifier::InvalidSignature) do
      @verifier.verify("purejunk")
    end
  end

  def test_alternative_serialization_method
    prev = ActiveSupport.use_standard_json_time_format
    ActiveSupport.use_standard_json_time_format = true
    verifier = ActiveSupport::LegacyMessageVerifier.new("Hey, I'm a secret!", :serializer => JSONSerializer.new)
    message = verifier.generate({ :foo => 123, 'bar' => Time.utc(2010) })
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
    valid_message = "BAh7BjoIZm9vUzotTGVnYWN5TWVzc2FnZVZlcmlmaWVyVGVzdDo6QXV0b2xvYWRDbGFzcwY7AEkiCGZvbwY6BkVU--3d1a42a9c6f47ca339a48648d7fe383c5ebe1461"
    exception = assert_raise(ArgumentError, NameError) do
      @verifier.verified(valid_message)
    end
    assert_includes ["uninitialized constant LegacyMessageVerifierTest::AutoloadClass",
                    "undefined class/module LegacyMessageVerifierTest::AutoloadClass"], exception.message
    exception = assert_raise(ArgumentError, NameError) do
      @verifier.verify(valid_message)
    end
    assert_includes ["uninitialized constant LegacyMessageVerifierTest::AutoloadClass",
                    "undefined class/module LegacyMessageVerifierTest::AutoloadClass"], exception.message
  end

  def test_raise_error_when_secret_is_nil
    exception = assert_raise(ArgumentError) do
      ActiveSupport::LegacyMessageVerifier.new(nil)
    end
    assert_equal exception.message, 'Secret should not be nil.'
  end
end
