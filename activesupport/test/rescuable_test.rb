require 'abstract_unit'

class WraithAttack < StandardError
end

class NuclearExplosion < StandardError
end

class MadRonon < StandardError
  attr_accessor :message
  
  def initialize(message)
    @message = message
    super()
  end
end

class Stargate
  attr_accessor :result

  include ActiveSupport::Rescuable

  rescue_from WraithAttack, :with => :sos

  rescue_from NuclearExplosion do
    @result = 'alldead'
  end
  
  rescue_from MadRonon do |e|
    @result = e.message
  end

  def dispatch(method)
    send(method)
  rescue Exception => e
    rescue_with_handler(e)
  end

  def attack
    raise WraithAttack
  end

  def nuke
    raise NuclearExplosion
  end

  def ronanize
    raise MadRonon.new("dex")
  end

  def sos
    @result = 'killed'
  end
end

class RescueableTest < Test::Unit::TestCase
  def setup
    @stargate = Stargate.new
  end

  def test_rescue_from_with_method
    @stargate.dispatch :attack
    assert_equal 'killed', @stargate.result
  end
  
  def test_rescue_from_with_block
    @stargate.dispatch :nuke
    assert_equal 'alldead', @stargate.result
  end
  
  def test_rescue_from_with_block_with_args
    @stargate.dispatch :ronanize
    assert_equal 'dex', @stargate.result
  end  
end
