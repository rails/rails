require 'abstract_unit'

class WraithAttack < StandardError
end

class NuclearExplosion < StandardError
end

class MadRonon < StandardError
end

class CoolError < StandardError
end

class Stargate
  attr_accessor :result

  include ActiveSupport::Rescuable

  rescue_from WraithAttack, :with => :sos_first

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

  def sos_first
    @result = 'sos_first'
  end

end

class CoolStargate < Stargate
  attr_accessor :result

  include ActiveSupport::Rescuable

  rescue_from CoolError, :with => :sos_cool_error

  def sos_cool_error
    @result = 'sos_cool_error'
  end
end


class RescuableTest < ActiveSupport::TestCase
  def setup
    @stargate = Stargate.new
    @cool_stargate = CoolStargate.new
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

  def test_rescues_defined_later_are_added_at_end_of_the_rescue_handlers_array
    expected = ["WraithAttack", "WraithAttack", "NuclearExplosion", "MadRonon"]
    result = @stargate.send(:rescue_handlers).collect {|e| e.first}
    assert_equal expected, result
  end

  def test_children_should_inherit_rescue_defintions_from_parents_and_child_rescue_should_be_appended
    expected = ["WraithAttack", "WraithAttack", "NuclearExplosion", "MadRonon", "CoolError"]
    result = @cool_stargate.send(:rescue_handlers).collect {|e| e.first}
    assert_equal expected, result
  end

end
