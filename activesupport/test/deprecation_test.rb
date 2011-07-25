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

  def test_several_behaviors
    @a, @b = nil, nil

    ActiveSupport::Deprecation.behavior = [
      Proc.new { |msg, callstack| @a = msg },
      Proc.new { |msg, callstack| @b = msg }
    ]

    @dtc.partially
    assert_match(/foo=nil/, @a)
    assert_match(/foo=nil/, @b)
  end

  def test_default_stderr_behavior
    ActiveSupport::Deprecation.behavior = :stderr
    behavior = ActiveSupport::Deprecation.behavior.first

    content = capture(:stderr) {
      assert_nil behavior.call('Some error!', ['call stack!'])
    }
    assert_match(/Some error!/, content)
    assert_match(/call stack!/, content)
  end

  def test_default_silence_behavior
    ActiveSupport::Deprecation.behavior = :silence
    behavior = ActiveSupport::Deprecation.behavior.first

    assert_blank capture(:stderr) {
      assert_nil behavior.call('Some error!', ['call stack!'])
    }
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
  rescue MiniTest::Assertion
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

  def test_assert_deprecated_warn_work_with_default_behavior
    ActiveSupport::Deprecation.instance_variable_set('@behavior' , nil)
    assert_deprecated('abc') do
      ActiveSupport::Deprecation.warn 'abc'
    end
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

  def test_deprecation_in_other_module_does_not_interfere
    messages = []

    m = Module.new
    m.extend ActiveSupport::Deprecation
    m.behavior = Proc.new{|message, callstack| messages << message}
    assert_not_deprecated do # not globally
      assert_difference("messages.size") do # but locally
        m.warn("warning")
      end
    end
  end

  def test_deprecated_method_with_deprecator_implemented
    deprecator = deprecator_with_messages
    def deprecator.deprecated_method_warning(method, *params)
      "deprecator.deprecated_method_warning.#{method}"
    end

    deprecatee = Class.new() do
      def method
      end
      deprecate :method
      define_method(:deprecator){ deprecator }
    end

    deprecatee.new.method
    assert deprecator.messages.first.match("DEPRECATION WARNING: deprecator.deprecated_method_warning.method")
  end

  def test_deprecated_constant_with_deprecator_given
    deprecator = deprecator_with_messages
    klass = Class.new()
    klass.const_set(:OLD, ActiveSupport::Deprecation::DeprecatedConstantProxy.new('klass::OLD', 'Object', deprecator) )
    assert_difference("deprecator.messages.size") do
      klass::OLD.to_s
    end
  end
  
  def test_deprecated_instance_variable_with_instance_deprecator
    deprecator = deprecator_with_messages
    
    klass = Class.new() do
      def initialize
        @request = ActiveSupport::Deprecation::DeprecatedInstanceVariableProxy.new(self, :request)
        @_request = :a_request
      end
      def request; @_request end
      def old_request; @request end
      define_method(:deprecator) { deprecator }
    end

    assert_difference("deprecator.messages.size") { klass.new.old_request.to_s }
    
  end

  def test_deprecated_instance_variable_with_given_deprecator
    deprecator = deprecator_with_messages

    klass = Class.new() do
      define_method(:initialize) do
        @request = ActiveSupport::Deprecation::DeprecatedInstanceVariableProxy.new(self, :request, :@request, deprecator)
        @_request = :a_request
      end
      def request; @_request end
      def old_request; @request end
    end

    assert_difference("deprecator.messages.size") { klass.new.old_request.to_s }
  end

  def test_included_deprecation_module
    klass = Class.new() do
      attr_reader :last_message
      include ActiveSupport::Deprecation
      def deprecated_method
        warn(deprecated_method_warning(:deprecated_method, "You are calling deprecated method"))
      end

      private

      def deprecated_method_warning(method_name, message = nil)
        message || "#{method_name} is deprecated and will be removed from This Library"
      end

      def behavior
        @behavior ||= [Proc.new { |message| @last_message = message }]
      end
    end

    object = klass.new
    object.deprecated_method
    assert_match(/You are calling deprecated method/, object.last_message)
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


  private


  def deprecator_with_messages
    deprecator = Object.new
    deprecator.extend(ActiveSupport::Deprecation)
    deprecator.behavior = Proc.new{|message, callstack| deprecator.messages << message}
    def deprecator.messages
      @messages ||= []
    end
    deprecator
  end
end
