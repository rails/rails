require 'abstract_unit'

class MessageVerifierTest < Test::Unit::TestCase
  def setup
    @verifier = ActiveSupport::MessageVerifier.new("Hey, I'm a secret!")
    @data = {:some=>"data", :now=>Time.now}
  end
  
  def test_simple_round_tripping
    message = @verifier.generate(@data)
    assert_equal @data, @verifier.verify(message)
  end
  
  def test_tampered_data_raises
    data, hash = @verifier.generate(@data).split("--")
    assert_not_verified("#{data.reverse}--#{hash}")
    assert_not_verified("#{data}--#{hash.reverse}")
  end
  
  def assert_not_verified(message)
    assert_raise(ActiveSupport::MessageVerifier::InvalidSignature) do
      @verifier.verify(message)
    end
  end
end
