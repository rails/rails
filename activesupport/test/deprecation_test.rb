# frozen_string_literal: true

require_relative "abstract_unit"
require "logger"
require "stringio"
require "active_support/core_ext/enumerable"
require "active_support/testing/stream"

class Deprecatee
  attr_accessor :fubar, :foo_bar

  def zero() 0 end
  def one(a) a end
  def multi(a, b, c) [a, b, c] end
end

module Undeprecated
  module Foo
    BAR = "foo bar"
  end

  class Error < StandardError; end
end

class DeprecationTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Stream

  def setup
    @original_configuration = get_configuration(ActiveSupport::Deprecation)
    @deprecator = ActiveSupport::Deprecation
  end

  def teardown
    set_configuration(ActiveSupport::Deprecation, @original_configuration)
  end

  test "assert_deprecated" do
    assert_deprecated(/fubar/, @deprecator) do
      @deprecator.warn("using fubar is deprecated")
    end
  end

  test "assert_not_deprecated" do
    assert_not_deprecated(@deprecator) do
      1 + 1
    end
  end

  test "Module::deprecate" do
    klass = Class.new(Deprecatee)
    klass.deprecate :zero, :one, :multi, deprecator: @deprecator

    assert_deprecated(/zero is deprecated/, @deprecator) do
      assert_equal 0, klass.new.zero
    end

    assert_deprecated(/one is deprecated/, @deprecator) do
      assert_equal 1, klass.new.one(1)
    end

    assert_deprecated(/multi is deprecated/, @deprecator) do
      assert_equal [1, 2, 3], klass.new.multi(1, 2, 3)
    end
  end

  test "Module::deprecate does not expand Hash positional argument" do
    klass = Class.new(Deprecatee)
    klass.deprecate :one, :one!, deprecator: @deprecator
    klass.alias_method :one!, :one

    hash = { k: 1 }

    assert_deprecated(/one is deprecated/, @deprecator) do
      assert_same hash, klass.new.one(hash)
    end

    assert_deprecated(/one! is deprecated/, @deprecator) do
      assert_same hash, klass.new.one!(hash)
    end
  end

  test "DeprecatedObjectProxy" do
    deprecated_object = ActiveSupport::Deprecation::DeprecatedObjectProxy.new(Object.new, ":bomb:", @deprecator)
    assert_deprecated(/:bomb:/, @deprecator) { deprecated_object.to_s }
  end

  test "nil behavior is ignored" do
    @deprecator.behavior = nil
    assert_deprecated("fubar", @deprecator) { @deprecator.warn("fubar") }
  end

  test "multiple behaviors" do
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

  test ":raise behavior" do
    @deprecator.behavior = :raise

    message   = "Revise this deprecated stuff now!"
    callstack = caller_locations

    e = assert_raise ActiveSupport::DeprecationException do
      @deprecator.behavior.first.call(message, callstack, "horizon", "gem")
    end
    assert_equal message, e.message
    assert_equal callstack.map(&:to_s), e.backtrace.map(&:to_s)
  end

  test ":stderr behavior" do
    @deprecator.behavior = :stderr
    behavior = @deprecator.behavior.first

    content = capture(:stderr) {
      assert_nil behavior.call("Some error!", ["call stack!"], "horizon", "gem")
    }
    assert_match(/Some error!/, content)
    assert_match(/call stack!/, content)
  end

  test ":stderr behavior with #warn" do
    @deprecator.behavior = :stderr

    content = capture(:stderr) {
      @deprecator.warn("Instance error!", ["instance call stack!"])
    }

    assert_match(/Instance error!/, content)
    assert_match(/instance call stack!/, content)
  end

  test ":log behavior" do
    @deprecator.behavior = :log
    output = StringIO.new

    with_rails_logger(Logger.new(output)) do
      @deprecator.behavior.first.call("fubar", ["call stack"], "horizon", "gem")
    end

    assert_match "fubar", output.string
  end

  test ":log behavior without Rails.logger" do
    @deprecator.behavior = :log

    _out, err = capture_io do
      with_rails_logger(nil) do
        @deprecator.behavior.first.call("fubar", ["call stack"], "horizon", "gem")
      end
    end

    assert_match "fubar", err
  end

  test ":silence behavior" do
    @deprecator.behavior = :silence
    behavior = @deprecator.behavior.first

    stderr_output = capture(:stderr) {
      assert_nil behavior.call("Some error!", ["call stack!"], "horizon", "gem")
    }
    assert_empty stderr_output
  end

  test ":notify behavior" do
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

  test "invalid behavior" do
    e = assert_raises(ArgumentError) do
      @deprecator.behavior = :invalid
    end

    assert_equal ":invalid is not a valid deprecation behavior.", e.message
  end

  test "callable object behavior" do
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

  test "DeprecatedInstanceVariableProxy" do
    instance = Deprecatee.new
    instance.fubar = ActiveSupport::Deprecation::DeprecatedInstanceVariableProxy.new(instance, :foo_bar, "@fubar", @deprecator)
    instance.foo_bar = "foo bar!"

    fubar_size = assert_deprecated("@fubar.size", @deprecator) { instance.fubar.size }
    assert_equal instance.foo_bar.size, fubar_size

    fubar_s = assert_deprecated("@fubar.to_s", @deprecator) { instance.fubar.to_s }
    assert_equal instance.foo_bar.to_s, fubar_s
  end

  test "DeprecatedInstanceVariableProxy does not warn on inspect" do
    instance = Deprecatee.new
    instance.fubar = ActiveSupport::Deprecation::DeprecatedInstanceVariableProxy.new(instance, :foo_bar, "@fubar", @deprecator)
    instance.foo_bar = "foo bar!"

    fubar_inspected = assert_not_deprecated(@deprecator) { instance.fubar.inspect }
    assert_equal instance.foo_bar.inspect, fubar_inspected
  end

  test "DeprecatedConstantProxy" do
    proxy = ActiveSupport::Deprecation::DeprecatedConstantProxy.new("FUBAR", "Undeprecated::Foo::BAR", @deprecator)

    assert_deprecated("FUBAR", @deprecator) do
      assert_equal Undeprecated::Foo::BAR, proxy
    end
  end

  test "DeprecatedConstantProxy does not warn on .class" do
    proxy = ActiveSupport::Deprecation::DeprecatedConstantProxy.new("FUBAR", "Undeprecated::Foo::BAR", @deprecator)

    fubar_class = assert_not_deprecated(@deprecator) { proxy.class }
    assert_equal Undeprecated::Foo::BAR.class, fubar_class
  end

  test "DeprecatedConstantProxy with child constant" do
    proxy = ActiveSupport::Deprecation::DeprecatedConstantProxy.new("Fuu", "Undeprecated::Foo", @deprecator)

    assert_deprecated("Fuu", @deprecator) do
      assert_equal Undeprecated::Foo::BAR, proxy::BAR
    end

    assert_deprecated("Fuu", @deprecator) do
      assert_raises(NameError) { proxy::DOES_NOT_EXIST }
    end
  end

  test "deprecate_constant" do
    legacy = Module.new { def self.name; "Legacy"; end }
    legacy.include ActiveSupport::Deprecation::DeprecatedConstantAccessor
    legacy.deprecate_constant "FUBAR", "Undeprecated::Foo::BAR", deprecator: @deprecator

    assert_deprecated("Legacy::FUBAR", @deprecator) do
      assert_equal Undeprecated::Foo::BAR, legacy::FUBAR
    end
  end

  test "deprecate_constant when rescuing a deprecated error" do
    legacy = Module.new { def self.name; "Legacy"; end }
    legacy.include ActiveSupport::Deprecation::DeprecatedConstantAccessor
    legacy.deprecate_constant "Error", "Undeprecated::Error", deprecator: @deprecator

    assert_deprecated("Legacy::Error", @deprecator) do
      assert_nothing_raised do
        raise Undeprecated::Error
      rescue legacy::Error
      end
    end
  end

  test "assert_deprecated raises when no deprecation warning" do
    assert_raises(Minitest::Assertion) do
      assert_deprecated(/./, @deprecator) { 1 + 1 }
    end
  end

  test "assert_not_deprecated raises when some deprecation warning" do
    assert_raises(Minitest::Assertion) do
      assert_not_deprecated(@deprecator) { @deprecator.warn }
    end
  end

  test "assert_deprecated without match argument" do
    assert_deprecated do
      ActiveSupport::Deprecation.warn
    end
  end

  test "assert_deprecated matches any warning from block" do
    assert_deprecated("abc", @deprecator) do
      @deprecator.warn "abc"
      @deprecator.warn "def"
    end
  rescue Minitest::Assertion
    flunk "assert_deprecated should match any warning in block, not just the last one"
  end

  test "assert_not_deprecated returns result of block" do
    assert_equal 123, assert_not_deprecated(@deprecator) { 123 }
  end

  test "assert_deprecated_returns result of block" do
    result = assert_deprecated("abc", @deprecator) do
      @deprecator.warn "abc"
      123
    end
    assert_equal 123, result
  end

  test "silence" do
    assert_not @deprecator.silenced

    @deprecator.silence do
      assert_not_deprecated(@deprecator) { @deprecator.warn }
    end

    assert_deprecated(/./, @deprecator) { @deprecator.warn }

    @deprecator.silenced = true
    assert @deprecator.silenced

    assert_not_deprecated(@deprecator) { @deprecator.warn }
  end

  test "silence only affects the current thread" do
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

  test "Module::deprecate with method name only" do
    klass = Class.new(Deprecatee)
    klass.deprecate :fubar, :fubar=, deprecator: @deprecator

    assert_deprecated(/./, @deprecator) { klass.new.fubar }
    assert_deprecated(/./, @deprecator) { klass.new.fubar = :foo }
  end

  test "Module::deprecate with alternative method" do
    klass = Class.new(Deprecatee)
    klass.deprecate fubar: :foo_bar, deprecator: @deprecator

    assert_deprecated(/use foo_bar instead/, @deprecator) { klass.new.fubar }
  end

  test "Module::deprecate with message" do
    klass = Class.new(Deprecatee)
    klass.deprecate fubar: "this is the old way", deprecator: @deprecator

    assert_deprecated(/this is the old way/, @deprecator) { klass.new.fubar }
  end

  test "delegating to ActiveSupport::Deprecation" do
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

  test "overriding deprecated_method_warning" do
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

  test "Module::deprecate with custom deprecator" do
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

  test "DeprecatedConstantProxy with explicit deprecator" do
    deprecator = deprecator_with_messages
    klass = Class.new
    klass.const_set(:OLD, ActiveSupport::Deprecation::DeprecatedConstantProxy.new("klass::OLD", "Object", deprecator))
    assert_difference("deprecator.messages.size") do
      klass::OLD.to_s
    end
  end

  test "DeprecatedConstantProxy with message" do
    deprecator = deprecator_with_messages

    klass = Class.new
    klass.const_set(:OLD, ActiveSupport::Deprecation::DeprecatedConstantProxy.new("klass::OLD", "Object", deprecator, message: "foo"))

    klass::OLD.to_s
    assert_match "foo", deprecator.messages.last
  end

  test "default deprecation_horizon is greater than the current Rails version" do
    assert_operator ActiveSupport::Deprecation.new.deprecation_horizon, :>, ActiveSupport::VERSION::STRING
  end

  test "default gem_name is Rails" do
    deprecator = ActiveSupport::Deprecation.new

    deprecator.send(:deprecated_method_warning, :deprecated_method, "You are calling deprecated method").tap do |message|
      assert_match(/is deprecated and will be removed from Rails/, message)
    end
  end

  test "custom gem_name" do
    deprecator = ActiveSupport::Deprecation.new("2.0", "Custom")

    deprecator.send(:deprecated_method_warning, :deprecated_method, "You are calling deprecated method").tap do |message|
      assert_match(/is deprecated and will be removed from Custom/, message)
    end
  end

  test "Module::deprecate can be called before the target method is defined" do
    klass = Class.new(Deprecatee)
    klass.deprecate :multi!, deprecator: @deprecator
    klass.alias_method :multi!, :multi

    assert_deprecated(/multi! is deprecated/, @deprecator) do
      assert_equal [1, 2, 3], klass.new.multi!(1, 2, 3)
    end
  end

  test "warn with empty callstack" do
    @deprecator.behavior = :silence

    assert_nothing_raised do
      @deprecator.warn("message", [])
      Thread.new { @deprecator.warn("message") }.join
    end
  end

  test "disallowed_warnings is empty by default" do
    assert_equal @deprecator.disallowed_warnings, []
  end

  test "disallowed_warnings can be configured" do
    config_warnings = ["unsafe_method is going away"]
    @deprecator.disallowed_warnings = config_warnings
    assert_equal @deprecator.disallowed_warnings, config_warnings
  end

  test "disallowed_behavior does not trigger when disallowed_warnings is empty" do
    @deprecator.disallowed_behavior = proc { flunk }

    assert_deprecated(/fubar/, @deprecator) do
      @deprecator.warn("using fubar is deprecated")
    end
  end

  test "disallowed_behavior does not trigger when disallowed_warnings does not match the warning" do
    @deprecator.disallowed_behavior = proc { flunk }
    @deprecator.disallowed_warnings = ["foo bar"]

    assert_deprecated(/fubar/, @deprecator) do
      @deprecator.warn("using fubar is deprecated")
    end
  end

  test "disallowed_warnings can match using a substring" do
    @deprecator.disallowed_warnings = ["fubar"]

    assert_disallowed(/fubar/, @deprecator) do
      @deprecator.warn("using fubar is deprecated")
    end
  end

  test "disallowed_warnings can match using a substring as a symbol" do
    @deprecator.disallowed_warnings = [:fubar]

    assert_disallowed(/fubar/, @deprecator) do
      @deprecator.warn("using fubar is deprecated")
    end
  end

  test "disallowed_warnings can match using a regexp" do
    @deprecator.disallowed_warnings = [/f[aeiou]+bar/]

    assert_disallowed(/fubar/, @deprecator) do
      @deprecator.warn("using fubar is deprecated")
    end
  end

  test "disallowed_warnings matches all warnings when set to :all" do
    @deprecator.disallowed_warnings = :all

    assert_disallowed(/fubar/, @deprecator) do
      @deprecator.warn("using fubar is deprecated")
    end
  end

  test "different behaviors for allowed and disallowed warnings" do
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

  test "allow" do
    @deprecator.disallowed_warnings = :all

    assert_disallowed(/./, @deprecator) { @deprecator.warn }

    @deprecator.allow do
      assert_deprecated(/./, @deprecator) { @deprecator.warn }
    end
  end

  test "allow only allows matching warnings using a substring" do
    @deprecator.disallowed_warnings = :all

    @deprecator.allow(["foo bar", "baz qux"]) do
      assert_deprecated(/foo bar/, @deprecator) { @deprecator.warn("foo bar") }
      assert_deprecated(/baz qux/, @deprecator) { @deprecator.warn("baz qux") }
      assert_disallowed(/fubar/, @deprecator) { @deprecator.warn("fubar") }
    end
  end

  test "allow only allows matching warnings using a substring as a symbol" do
    @deprecator.disallowed_warnings = :all

    @deprecator.allow([:"foo bar", :"baz qux"]) do
      assert_deprecated(/foo bar/, @deprecator) { @deprecator.warn("foo bar") }
      assert_deprecated(/baz qux/, @deprecator) { @deprecator.warn("baz qux") }
      assert_disallowed(/fubar/, @deprecator) { @deprecator.warn("fubar") }
    end
  end

  test "allow only allows matching warnings using a regexp" do
    @deprecator.disallowed_warnings = :all

    @deprecator.allow([/(foo|baz) (bar|qux)/]) do
      assert_deprecated(/foo bar/, @deprecator) { @deprecator.warn("foo bar") }
      assert_deprecated(/baz qux/, @deprecator) { @deprecator.warn("baz qux") }
      assert_disallowed(/fubar/, @deprecator) { @deprecator.warn("fubar") }
    end
  end

  test "allow only affects its block" do
    @deprecator.disallowed_warnings = :all

    @deprecator.allow do
      assert_deprecated(/./, @deprecator) { @deprecator.warn }
    end

    assert_disallowed(/./, @deprecator) { @deprecator.warn }
  end

  test "allow only affects the current thread" do
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

  test "allow with :if option" do
    @deprecator.disallowed_warnings = :all

    @deprecator.allow("fubar", if: true) do
      assert_deprecated(/fubar/, @deprecator) { @deprecator.warn("fubar") }
    end

    @deprecator.allow("fubar", if: false) do
      assert_disallowed(/fubar/, @deprecator) { @deprecator.warn("fubar") }
    end
  end

  test "allow with :if option as a proc" do
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

    module ::Rails; end

    def with_rails_logger(logger)
      ::Rails.singleton_class.class_eval do
        alias_method :__original_logger, :logger if method_defined?(:logger)
        define_method(:logger) { logger }
      end

      yield logger
    ensure
      ::Rails.singleton_class.class_eval do
        if method_defined?(:__original_logger)
          alias_method :logger, :__original_logger
          undef_method :__original_logger
        else
          undef_method :logger
        end
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
