# frozen_string_literal: true

require_relative 'abstract_unit'

class WraithAttack < StandardError
end

class MadRonon < StandardError
end

class CoolError < StandardError
end

module WeirdError
  def self.===(other)
    Exception === other && other.respond_to?(:weird?)
  end
end

class Stargate
  # Nest this so the 'NuclearExplosion' handler needs a lexical const_get
  # to find it.
  class NuclearExplosion < StandardError; end

  attr_accessor :result

  include ActiveSupport::Rescuable

  rescue_from WraithAttack, with: :sos_first

  rescue_from WraithAttack, with: :sos

  rescue_from 'NuclearExplosion' do
    @result = 'alldead'
  end

  rescue_from MadRonon do |e|
    @result = e.message
  end

  rescue_from WeirdError do
    @result = 'weird'
  end

  def dispatch(method)
    send(method)
  rescue Exception => e
    unless rescue_with_handler(e)
      @result = 'unhandled'
    end
  end

  def attack
    raise WraithAttack
  end

  def nuke
    raise NuclearExplosion
  end

  def ronanize
    raise MadRonon.new('dex')
  end

  def crash
    raise 'unhandled RuntimeError'
  end

  def looped_crash
    ex1 = StandardError.new('error 1')
    ex2 = StandardError.new('error 2')
    begin
      begin
        raise ex1
      rescue
        # sets the cause on ex2 to be ex1
        raise ex2
      end
    rescue
      # sets the cause on ex1 to be ex2
      raise ex1
    end
  end

  def fall_back_to_cause
    # This exception is the cause and has a handler.
    ronanize
  rescue
    # This is the exception we'll handle that doesn't have a cause.
    raise 'unhandled RuntimeError with a handleable cause'
  end

  def weird
    StandardError.new.tap do |exc|
      def exc.weird?
        true
      end

      raise exc
    end
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

  rescue_from CoolError, with: :sos_cool_error

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

  def test_rescue_from_error_dispatchers_with_case_operator
    @stargate.dispatch :weird
    assert_equal 'weird', @stargate.result
  end

  def test_rescues_defined_later_are_added_at_end_of_the_rescue_handlers_array
    expected = ['WraithAttack', 'WraithAttack', 'NuclearExplosion', 'MadRonon', 'WeirdError']
    result = @stargate.send(:rescue_handlers).collect(&:first)
    assert_equal expected, result
  end

  def test_children_should_inherit_rescue_definitions_from_parents_and_child_rescue_should_be_appended
    expected = ['WraithAttack', 'WraithAttack', 'NuclearExplosion', 'MadRonon', 'WeirdError', 'CoolError']
    result = @cool_stargate.send(:rescue_handlers).collect(&:first)
    assert_equal expected, result
  end

  def test_rescue_falls_back_to_exception_cause
    @stargate.dispatch :fall_back_to_cause
    assert_equal 'dex', @stargate.result
  end

  def test_unhandled_exceptions
    @stargate.dispatch(:crash)
    assert_equal 'unhandled', @stargate.result
  end

  def test_rescue_handles_loops_in_exception_cause_chain
    @stargate.dispatch :looped_crash
    assert_equal 'unhandled', @stargate.result
  end
end
