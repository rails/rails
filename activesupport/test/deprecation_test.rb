require 'abstract_unit'

class Deprecatee
  def initialize
    @request = ActiveSupport::Deprecation::DeprecatedInstanceVariableProxy.new(self, :request)
    @_request = 'there we go'
  end
  def request; @_request end
  def old_request; @request end

  def partially(foo = nil)
    ActiveSupport::Deprecation.warn('calling with foo=nil is out', caller) if foo.nil?
  end

  def not() 2 end
  def none() 1 end
  def one(a) a end
  def multi(a,b,c) [a,b,c] end
  deprecate :none, :one, :multi

  def a; end
  def b; end
  def c; end
  def d; end
  def e; end
  deprecate :a, :b, :c => :e, :d => "you now need to do something extra for this one"

  def f=(v); end
  deprecate :f=

  module B
    C = 1
  end
  A = ActiveSupport::Deprecation::DeprecatedConstantProxy.new('Deprecatee::A', 'Deprecatee::B::C')
end


class DeprecationTest < ActiveSupport::TestCase
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
    assert_deprecated(/none is deprecated.*test_deprecate_class_method at/) do
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

  def test_deprecated_instance_variable_proxy
    assert_not_deprecated { @dtc.request.size }

    assert_deprecated('@request.size') { assert_equal @dtc.request.size, @dtc.old_request.size }
    assert_deprecated('@request.to_s') { assert_equal @dtc.request.to_s, @dtc.old_request.to_s }
  end

  def test_deprecated_instance_variable_proxy_shouldnt_warn_on_inspect
    assert_not_deprecated { assert_equal @dtc.request.inspect, @dtc.old_request.inspect }
  end

  def test_deprecated_constant_proxy
    assert_not_deprecated { Deprecatee::B::C }
    assert_deprecated('Deprecatee::A') { assert_equal Deprecatee::B::C, Deprecatee::A }
  end

  def test_assert_deprecation_without_match
    assert_deprecated do
      @dtc.partially
    end
  end

  def test_assert_deprecated_matches_any_warning
    assert_deprecated 'abc' do
      ActiveSupport::Deprecation.warn 'abc'
      ActiveSupport::Deprecation.warn 'def'
    end
  rescue Test::Unit::AssertionFailedError
    flunk 'assert_deprecated should match any warning in block, not just the last one'
  end

  def test_assert_not_deprecated_returns_result_of_block
    assert_equal 123, assert_not_deprecated { 123 }
  end

  def test_assert_deprecated_returns_result_of_block
    result = assert_deprecated('abc') do
      ActiveSupport::Deprecation.warn 'abc'
      123
    end
    assert_equal 123, result
  end

  def test_silence
    ActiveSupport::Deprecation.silence do
      assert_not_deprecated { @dtc.partially }
    end

    ActiveSupport::Deprecation.silenced = true
    assert_not_deprecated { @dtc.partially }
    ActiveSupport::Deprecation.silenced = false
  end

  def test_deprecation_without_explanation
    assert_deprecated { @dtc.a }
    assert_deprecated { @dtc.b }
    assert_deprecated { @dtc.f = :foo }
  end

  def test_deprecation_with_alternate_method
    assert_deprecated(/use e instead/) { @dtc.c }
  end

  def test_deprecation_with_explicit_message
    assert_deprecated(/you now need to do something extra for this one/) { @dtc.d }
  end

  unless defined?(::MiniTest)
    def test_assertion_failed_error_doesnt_spout_deprecation_warnings
      error_class = Class.new(StandardError) do
        def message
          ActiveSupport::Deprecation.warn 'warning in error message'
          super
        end
      end

      raise error_class.new('hmm')

    rescue => e
      error = Test::Unit::Error.new('testing ur doodz', e)
      assert_not_deprecated { error.message }
      assert_nil @last_message
    end
  end
end
