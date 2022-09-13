# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/core_ext/enumerable"
require "active_support/testing/stream"

class Deprecatee
  def initialize
    @request = ActiveSupport::Deprecation::DeprecatedInstanceVariableProxy.new(self, :request)
    @_request = "there we go"
  end
  def request; @_request end
  def old_request; @request end

  def not() 2 end
  def none() 1 end
  def one(a) a end
  def multi(a, b, c) [a, b, c] end
  deprecate :none, :one, :multi

  def a; end
  def b; end
  def c; end
  def d; end
  def e; end
  deprecate :a, :b, c: :e, d: "you now need to do something extra for this one"

  def f=(v); end
  deprecate :f=

  deprecate :g
  def g(h) h end

  module B
    C = 1
  end
  A = ActiveSupport::Deprecation::DeprecatedConstantProxy.new("Deprecatee::A", "Deprecatee::B::C")

  module New
    class Descendant; end
  end
  Old = ActiveSupport::Deprecation::DeprecatedConstantProxy.new("Deprecatee::Old", "Deprecatee::New")
end

class DeprecateeWithAccessor
  include ActiveSupport::Deprecation::DeprecatedConstantAccessor

  module B
    C = 1
  end
  deprecate_constant "A", "DeprecateeWithAccessor::B::C"

  class NewException < StandardError; end
  deprecate_constant "OldException", "DeprecateeWithAccessor::NewException"
end

class DeprecationTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Stream

  def setup
    @original_configuration = get_configuration(ActiveSupport::Deprecation)
    @deprecator = ActiveSupport::Deprecation
    @dtc = Deprecatee.new
  end

  def teardown
    set_configuration(ActiveSupport::Deprecation, @original_configuration)
  end

  def test_inline_deprecation_warning
    assert_deprecated(/fubar/, @deprecator) do
      @deprecator.warn("using fubar is deprecated")
    end
  end

  def test_undeprecated
    assert_not_deprecated(@deprecator) do
      1 + 1
    end
  end

  def test_deprecate_method_on_class
    assert_deprecated(/none is deprecated/) do
      assert_equal 1, @dtc.none
    end

    assert_deprecated(/one is deprecated/) do
      assert_equal 1, @dtc.one(1)
    end

    assert_deprecated(/multi is deprecated/) do
      assert_equal [1, 2, 3], @dtc.multi(1, 2, 3)
    end
  end

  def test_deprecate_method_doesnt_expand_positional_argument_hash
    hash = { k: 1 }

    assert_deprecated(/one is deprecated/) do
      assert_same hash, @dtc.one(hash)
    end

    assert_deprecated(/g is deprecated/) do
      assert_same hash, @dtc.g(hash)
    end
  end

  def test_deprecate_object
    deprecated_object = ActiveSupport::Deprecation::DeprecatedObjectProxy.new(Object.new, ":bomb:")
    assert_deprecated(/:bomb:/) { deprecated_object.to_s }
  end

  def test_nil_behavior_is_ignored
    @deprecator.behavior = nil
    assert_deprecated("fubar", @deprecator) { @deprecator.warn("fubar") }
  end

  def test_several_behaviors
    @a, @b, @c = nil, nil, nil

    @deprecator.behavior = [
      lambda { |msg, callstack, horizon, gem| @a = msg },
      lambda { |msg, callstack| @b = msg },
      lambda { |*args| @c = args },
    ]

    @deprecator.warn("fubar")
    assert_match "fubar", @a
    assert_match "fubar", @b
    assert_equal 4, @c.size
  end

  def test_raise_behavior
    @deprecator.behavior = :raise

    message   = "Revise this deprecated stuff now!"
    callstack = caller_locations

    e = assert_raise ActiveSupport::DeprecationException do
      @deprecator.behavior.first.call(message, callstack, "horizon", "gem")
    end
    assert_equal message, e.message
    assert_equal callstack.map(&:to_s), e.backtrace.map(&:to_s)
  end

  def test_default_stderr_behavior
    @deprecator.behavior = :stderr
    behavior = @deprecator.behavior.first

    content = capture(:stderr) {
      assert_nil behavior.call("Some error!", ["call stack!"], "horizon", "gem")
    }
    assert_match(/Some error!/, content)
    assert_match(/call stack!/, content)
  end

  def test_default_stderr_behavior_with_warn_method
    @deprecator.behavior = :stderr

    content = capture(:stderr) {
      @deprecator.warn("Instance error!", ["instance call stack!"])
    }

    assert_match(/Instance error!/, content)
    assert_match(/instance call stack!/, content)
  end

  def test_default_silence_behavior
    @deprecator.behavior = :silence
    behavior = @deprecator.behavior.first

    stderr_output = capture(:stderr) {
      assert_nil behavior.call("Some error!", ["call stack!"], "horizon", "gem")
    }
    assert_empty stderr_output
  end

  def test_default_notify_behavior
    @deprecator.behavior = :notify
    behavior = @deprecator.behavior.first

    begin
      events = []
      ActiveSupport::Notifications.subscribe("deprecation.my_gem_custom") { |*args|
        events << args.extract_options!
      }

      assert_nil behavior.call("Some error!", ["call stack!"], "horizon", "MyGem::Custom")
      assert_equal 1, events.size
      assert_equal "Some error!", events.first[:message]
      assert_equal ["call stack!"], events.first[:callstack]
      assert_equal "horizon", events.first[:deprecation_horizon]
      assert_equal "MyGem::Custom", events.first[:gem_name]
    ensure
      ActiveSupport::Notifications.unsubscribe("deprecation.my_gem_custom")
    end
  end

  def test_default_invalid_behavior
    e = assert_raises(ArgumentError) do
      @deprecator.behavior = :invalid
    end

    assert_equal ":invalid is not a valid deprecation behavior.", e.message
  end

  def test_custom_behavior
    custom_behavior_class = Class.new do
      def call(message, callstack, horizon, gem_name)
        $stderr.puts message
      end
    end
    @deprecator.behavior = custom_behavior_class.new

    content = capture(:stderr) do
      @deprecator.warn("foo")
    end

    assert_match(/foo/, content)
  end

  def test_deprecated_instance_variable_proxy
    assert_not_deprecated { @dtc.request.size }

    assert_deprecated("@request.size") { assert_equal @dtc.request.size, @dtc.old_request.size }
    assert_deprecated("@request.to_s") { assert_equal @dtc.request.to_s, @dtc.old_request.to_s }
  end

  def test_deprecated_instance_variable_proxy_shouldnt_warn_on_inspect
    assert_not_deprecated { assert_equal @dtc.request.inspect, @dtc.old_request.inspect }
  end

  def test_deprecated_constant_proxy
    assert_not_deprecated { Deprecatee::B::C }
    assert_deprecated("Deprecatee::A") { assert_equal Deprecatee::B::C, Deprecatee::A }
    assert_not_deprecated { assert_equal Deprecatee::B::C.class, Deprecatee::A.class }
  end

  def test_deprecated_constant_descendant
    assert_not_deprecated { Deprecatee::New::Descendant }

    assert_deprecated("Deprecatee::Old") do
      assert_equal Deprecatee::Old::Descendant, Deprecatee::New::Descendant
    end

    assert_raises(NameError) do
      assert_deprecated("Deprecatee::Old") { Deprecatee::Old::NON_EXISTENCE }
    end
  end

  def test_deprecated_constant_accessor
    assert_not_deprecated { DeprecateeWithAccessor::B::C }
    assert_deprecated("DeprecateeWithAccessor::A") { assert_equal DeprecateeWithAccessor::B::C, DeprecateeWithAccessor::A }
  end

  def test_deprecated_constant_accessor_exception
    ActiveSupport::Deprecation.behavior = :silence

    raise DeprecateeWithAccessor::NewException.new("Test")
  rescue DeprecateeWithAccessor::OldException => e
    assert_kind_of DeprecateeWithAccessor::NewException, e
  end

  def test_assert_deprecated_raises_when_method_not_deprecated
    assert_raises(Minitest::Assertion) do
      assert_deprecated(/./, @deprecator) { 1 + 1 }
    end
  end

  def test_assert_not_deprecated
    assert_raises(Minitest::Assertion) do
      assert_not_deprecated(@deprecator) { @deprecator.warn }
    end
  end

  def test_assert_deprecation_without_match
    assert_deprecated do
      ActiveSupport::Deprecation.warn
    end
  end

  def test_assert_deprecated_matches_any_warning
    assert_deprecated("abc", @deprecator) do
      @deprecator.warn "abc"
      @deprecator.warn "def"
    end
  rescue Minitest::Assertion
    flunk "assert_deprecated should match any warning in block, not just the last one"
  end

  def test_assert_not_deprecated_returns_result_of_block
    assert_equal 123, assert_not_deprecated(@deprecator) { 123 }
  end

  def test_assert_deprecated_returns_result_of_block
    result = assert_deprecated("abc", @deprecator) do
      @deprecator.warn "abc"
      123
    end
    assert_equal 123, result
  end

  def test_silence
    assert_not @deprecator.silenced

    @deprecator.silence do
      assert_not_deprecated(@deprecator) { @deprecator.warn }
    end

    assert_deprecated(/./, @deprecator) { @deprecator.warn }

    @deprecator.silenced = true
    assert @deprecator.silenced

    assert_not_deprecated(@deprecator) { @deprecator.warn }
  end

  def test_silence_threaded
    @deprecator.silence do
      assert_not_deprecated(@deprecator) { @deprecator.warn }

      Thread.new do
        assert_deprecated(/./, @deprecator) { @deprecator.warn }

        @deprecator.silence do
          assert_not_deprecated(@deprecator) { @deprecator.warn }
        end

        assert_deprecated(/./, @deprecator) { @deprecator.warn }
      end.join

      assert_not_deprecated(@deprecator) { @deprecator.warn }
    end
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

  def test_deprecation_in_other_object
    messages = []

    klass = Class.new do
      delegate :warn, :behavior=, to: ActiveSupport::Deprecation
    end

    o = klass.new
    o.behavior = Proc.new { |message, callstack| messages << message }
    assert_difference("messages.size") do
      o.warn("warning")
    end
  end

  def test_deprecated_method_with_custom_method_warning
    deprecator = deprecator_with_messages

    class << deprecator
      private
        def deprecated_method_warning(method, message)
          "deprecator.deprecated_method_warning.#{method}"
        end
    end

    deprecatee = Class.new do
      def method
      end
      deprecate :method, deprecator: deprecator
    end

    deprecatee.new.method
    assert deprecator.messages.first.match("DEPRECATION WARNING: deprecator.deprecated_method_warning.method")
  end

  def test_deprecate_with_custom_deprecator
    custom_deprecator = Struct.new(:deprecation_warning).new

    assert_called_with(custom_deprecator, :deprecation_warning, [:method, nil]) do
      klass = Class.new do
        def method
        end
        deprecate :method, deprecator: custom_deprecator
      end

      klass.new.method
    end
  end

  def test_deprecated_constant_with_deprecator_given
    deprecator = deprecator_with_messages
    klass = Class.new
    klass.const_set(:OLD, ActiveSupport::Deprecation::DeprecatedConstantProxy.new("klass::OLD", "Object", deprecator))
    assert_difference("deprecator.messages.size") do
      klass::OLD.to_s
    end
  end

  def test_deprecated_constant_with_custom_message
    deprecator = deprecator_with_messages

    klass = Class.new
    klass.const_set(:OLD, ActiveSupport::Deprecation::DeprecatedConstantProxy.new("klass::OLD", "Object", deprecator, message: "foo"))

    klass::OLD.to_s
    assert_match "foo", deprecator.messages.last
  end

  def test_deprecated_instance_variable_with_instance_deprecator
    deprecator = deprecator_with_messages

    klass = Class.new() do
      def initialize(deprecator)
        @request = ActiveSupport::Deprecation::DeprecatedInstanceVariableProxy.new(self, :request, :@request, deprecator)
        @_request = :a_request
      end
      def request; @_request end
      def old_request; @request end
    end

    assert_difference("deprecator.messages.size") { klass.new(deprecator).old_request.to_s }
  end

  def test_default_deprecation_horizon_should_always_bigger_than_current_rails_version
    assert_operator ActiveSupport::Deprecation.new.deprecation_horizon, :>, ActiveSupport::VERSION::STRING
  end

  def test_default_gem_name
    deprecator = ActiveSupport::Deprecation.new

    deprecator.send(:deprecated_method_warning, :deprecated_method, "You are calling deprecated method").tap do |message|
      assert_match(/is deprecated and will be removed from Rails/, message)
    end
  end

  def test_custom_gem_name
    deprecator = ActiveSupport::Deprecation.new("2.0", "Custom")

    deprecator.send(:deprecated_method_warning, :deprecated_method, "You are calling deprecated method").tap do |message|
      assert_match(/is deprecated and will be removed from Custom/, message)
    end
  end

  def test_deprecate_work_before_define_method
    assert_deprecated(/g is deprecated/) { @dtc.g(1) }
  end

  test "warn with empty callstack" do
    @deprecator.behavior = :silence

    assert_nothing_raised do
      @deprecator.warn("message", [])
      Thread.new { @deprecator.warn("message") }.join
    end
  end

  def test_config_disallows_no_deprecations_by_default
    assert_equal @deprecator.disallowed_warnings, []
  end

  def test_allows_configuration_of_disallowed_warnings
    config_warnings = ["unsafe_method is going away"]
    @deprecator.disallowed_warnings = config_warnings
    assert_equal @deprecator.disallowed_warnings, config_warnings
  end

  def test_no_disallowed_behavior_with_no_disallowed_messages
    @deprecator.disallowed_behavior = proc { flunk }

    assert_deprecated(/fubar/, @deprecator) do
      @deprecator.warn("using fubar is deprecated")
    end
  end

  def test_disallowed_behavior_does_not_apply_to_allowed_messages
    @deprecator.disallowed_behavior = proc { flunk }
    @deprecator.disallowed_warnings = ["foo bar"]

    assert_deprecated(/fubar/, @deprecator) do
      @deprecator.warn("using fubar is deprecated")
    end
  end

  def test_disallowed_behavior_when_disallowed_message_configured_with_substring
    @deprecator.disallowed_warnings = ["fubar"]

    assert_disallowed(/fubar/, @deprecator) do
      @deprecator.warn("using fubar is deprecated")
    end
  end

  def test_disallowed_behavior_when_disallowed_message_configured_with_symbol_treated_as_substring
    @deprecator.disallowed_warnings = [:fubar]

    assert_disallowed(/fubar/, @deprecator) do
      @deprecator.warn("using fubar is deprecated")
    end
  end

  def test_disallowed_behavior_when_disallowed_message_configured_with_regular_expression
    @deprecator.disallowed_warnings = [/f[aeiou]+bar/]

    assert_disallowed(/fubar/, @deprecator) do
      @deprecator.warn("using fubar is deprecated")
    end
  end

  def test_disallowed_behavior_when_disallowed_message_configured_with_scalar_symbol_all
    @deprecator.disallowed_warnings = :all

    assert_disallowed(/fubar/, @deprecator) do
      @deprecator.warn("using fubar is deprecated")
    end
  end

  def test_different_behaviors_for_allowed_and_disallowed_messages
    @a, @b, @c, @d = nil, nil, nil, nil

    @deprecator.behavior = [
      lambda { |msg, callstack, horizon, gem| @a = msg },
      lambda { |msg, callstack| @b = msg },
    ]

    @deprecator.disallowed_behavior = [
      lambda { |msg, callstack, horizon, gem| @c = msg },
      lambda { |msg, callstack| @d = msg },
    ]

    @deprecator.disallowed_warnings = ["fubar"]

    @deprecator.warn("using fubar is deprecated")
    @deprecator.warn("using foo bar is deprecated")

    assert_match(/foo bar/, @a)
    assert_match(/foo bar/, @b)
    assert_match(/fubar/, @d)
    assert_match(/fubar/, @c)
  end

  test "disallowed_warnings with the default warning message" do
    @deprecator.disallowed_warnings = :all
    assert_disallowed(/./, @deprecator) { @deprecator.warn }

    @deprecator.disallowed_warnings = ["fubar"]
    assert_deprecated(/./, @deprecator) { @deprecator.warn }
  end

  def test_allow
    @deprecator.disallowed_warnings = :all

    assert_disallowed(/./, @deprecator) { @deprecator.warn }

    @deprecator.allow do
      assert_deprecated(/./, @deprecator) { @deprecator.warn }
    end
  end

  def test_allow_only_matching_warnings
    @deprecator.disallowed_warnings = :all

    @deprecator.allow(["foo bar", "baz qux"]) do
      assert_deprecated(/foo bar/, @deprecator) { @deprecator.warn("foo bar") }
      assert_deprecated(/baz qux/, @deprecator) { @deprecator.warn("baz qux") }
      assert_disallowed(/fubar/, @deprecator) { @deprecator.warn("fubar") }
    end
  end

  def test_allow_with_symbol
    @deprecator.disallowed_warnings = :all

    @deprecator.allow([:"foo bar", :"baz qux"]) do
      assert_deprecated(/foo bar/, @deprecator) { @deprecator.warn("foo bar") }
      assert_deprecated(/baz qux/, @deprecator) { @deprecator.warn("baz qux") }
      assert_disallowed(/fubar/, @deprecator) { @deprecator.warn("fubar") }
    end
  end

  def test_allow_with_regexp
    @deprecator.disallowed_warnings = :all

    @deprecator.allow([/(foo|baz) (bar|qux)/]) do
      assert_deprecated(/foo bar/, @deprecator) { @deprecator.warn("foo bar") }
      assert_deprecated(/baz qux/, @deprecator) { @deprecator.warn("baz qux") }
      assert_disallowed(/fubar/, @deprecator) { @deprecator.warn("fubar") }
    end
  end

  def test_allow_only_has_effect_inside_provided_block
    @deprecator.disallowed_warnings = :all

    @deprecator.allow do
      assert_deprecated(/./, @deprecator) { @deprecator.warn }
    end

    assert_disallowed(/./, @deprecator) { @deprecator.warn }
  end

  def test_allow_only_has_effect_on_the_thread_on_which_it_was_called
    @deprecator.disallowed_warnings = :all

    @deprecator.allow do
      assert_deprecated(/./, @deprecator) { @deprecator.warn }

      Thread.new do
        assert_disallowed(/./, @deprecator) { @deprecator.warn }

        @deprecator.allow do
          assert_deprecated(/./, @deprecator) { @deprecator.warn }
        end

        assert_disallowed(/./, @deprecator) { @deprecator.warn }
      end.join

      assert_deprecated(/./, @deprecator) { @deprecator.warn }
    end
  end

  def test_is_a_noop_based_on_if_kwarg_truthy_or_falsey
    @deprecator.disallowed_warnings = :all

    @deprecator.allow("fubar", if: true) do
      assert_deprecated(/fubar/, @deprecator) { @deprecator.warn("fubar") }
    end

    @deprecator.allow("fubar", if: false) do
      assert_disallowed(/fubar/, @deprecator) { @deprecator.warn("fubar") }
    end
  end

  def test_is_a_noop_based_on_if_kwarg_using_proc
    @deprecator.disallowed_warnings = :all

    @deprecator.allow("fubar", if: -> { true }) do
      assert_deprecated(/fubar/, @deprecator) { @deprecator.warn("fubar") }
    end

    @deprecator.allow("fubar", if: -> { false }) do
      assert_disallowed(/fubar/, @deprecator) { @deprecator.warn("fubar") }
    end
  end

  test "allow with the default warning message" do
    @deprecator.disallowed_warnings = :all

    @deprecator.allow(:all) do
      assert_deprecated(/./, @deprecator) { @deprecator.warn }
    end

    @deprecator.allow(["fubar"]) do
      assert_disallowed(/./, @deprecator) { @deprecator.warn }
    end
  end

  private
    def deprecator_with_messages
      klass = Class.new(ActiveSupport::Deprecation)
      deprecator = klass.new
      deprecator.behavior = Proc.new { |message, callstack| deprecator.messages << message }
      def deprecator.messages
        @messages ||= []
      end
      deprecator
    end

    def get_configuration(deprecator)
      %i[
        debug
        silenced
        behavior
        disallowed_behavior
        disallowed_warnings
      ].index_with do |attribute|
        deprecator.public_send(attribute)
      end
    end

    def set_configuration(deprecator, configuration)
      configuration.each do |attribute, value|
        deprecator.public_send("#{attribute}=", value)
      end
    end

    # a la collect_deprecations
    def collect_disallowed(deprecator)
      original_disallowed_behavior = deprecator.disallowed_behavior
      disallowed = []
      deprecator.disallowed_behavior = proc { |message| disallowed << message }
      result = yield
      [result, disallowed]
    ensure
      deprecator.disallowed_behavior = original_disallowed_behavior
    end

    # a la assert_deprecated
    def assert_disallowed(match = nil, deprecator = ActiveSupport::Deprecation, &block)
      result, disallowed = collect_disallowed(deprecator, &block)
      assert_not_empty disallowed, "Expected a disallowed deprecation within the block but received none"
      if match
        match = Regexp.new(Regexp.escape(match)) unless match.is_a?(Regexp)
        assert disallowed.any?(match), "No disallowed deprecations matched #{match}: #{disallowed.inspect}"
      end
      result
    end
end
