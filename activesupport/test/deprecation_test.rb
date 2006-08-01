require File.dirname(__FILE__) + '/abstract_unit'

class Deprecatee
  def partially(foo = nil)
    ActiveSupport::Deprecation.warn 'calling with foo=nil is out' if foo.nil?
  end

  def not() 2 end
  def none() 1 end
  def one(a) a end
  def multi(a,b,c) [a,b,c] end
  deprecate :none, :one, :multi
end


class DeprecationTest < Test::Unit::TestCase
  def setup
    # Track the last warning.
    @old_behavior = ActiveSupport::Deprecation.behavior
    @last_message = nil
    ActiveSupport::Deprecation.behavior = Proc.new { |message| @last_message = message }

    @dtc = Deprecatee.new
  end

  def teardown
    ActiveSupport::Deprecation.behavior = @old_behavior
  end

  def test_inline_deprecation_warning
    assert_deprecated(/foo=nil/) do
      @dtc.partially
    end
  end

  def test_undeprecated
    assert_not_deprecated do
      assert_equal 2, @dtc.not
    end
  end

  def test_deprecate_class_method
    assert_deprecated(/none is deprecated/) do
      assert_equal 1, @dtc.none
    end

    assert_deprecated(/one is deprecated/) do
      assert_equal 1, @dtc.one(1)
    end

    assert_deprecated(/multi is deprecated/) do
      assert_equal [1,2,3], @dtc.multi(1,2,3)
    end
  end

  def test_nil_behavior_is_ignored
    ActiveSupport::Deprecation.behavior = nil
    assert_deprecated(/foo=nil/) { @dtc.partially }
  end
end
