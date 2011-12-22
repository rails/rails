require 'abstract_unit'

begin
  require 'openssl'
  OpenSSL::Digest::SHA1
rescue LoadError, NameError
  $stderr.puts "Skipping MessageVerifier test: broken OpenSSL install"
else

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
    @verifier = ActiveSupport::MessageVerifier.new("Hey, I'm a secret!")
    @data = { :some => "data", :now => Time.local(2010) }
  end

  def test_simple_round_tripping
    message = @verifier.generate(@data)
    assert_equal @data, @verifier.verify(message)
  end

  def test_missing_signature_raises
    assert_not_verified(nil)
    assert_not_verified("")
  end

  def test_tampered_data_raises
    data, hash = @verifier.generate(@data).split("--")
    assert_not_verified("#{data.reverse}--#{hash}")
    assert_not_verified("#{data}--#{hash.reverse}")
    assert_not_verified("purejunk")
  end
  
  def test_alternative_serialization_method
    verifier = ActiveSupport::MessageVerifier.new("Hey, I'm a secret!", :serializer => JSONSerializer.new)
    message = verifier.generate({ :foo => 123, 'bar' => Time.utc(2010) })
    assert_equal verifier.verify(message), { "foo" => 123, "bar" => "2010-01-01T00:00:00Z" }
  end
  
  def assert_not_verified(message)
    assert_raise(ActiveSupport::MessageVerifier::InvalidSignature) do
      @verifier.verify(message)
    end
  end
end

end
