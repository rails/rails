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
    @deprecator = ActiveSupport::Deprecation.new
  end

  test "assert_deprecated" do
    assert_deprecated(/fubar/, @deprecator) do
      @deprecator.warn("using fubar is deprecated")
    end

    assert_deprecated(@deprecator) do
      @deprecator.warn("whatever")
    end
  end

  test "assert_deprecated requires a deprecator" do
    assert_raises(ArgumentError) do
      assert_deprecated do
        ActiveSupport::Deprecation._instance.warn
      end
    end
  end

  test "assert_not_deprecated" do
    assert_not_deprecated(@deprecator) do
      1 + 1
    end
  end

  test "assert_not_deprecated requires a deprecator" do
    assert_raises(ArgumentError) do
      assert_not_deprecated { }
    end
  end

  test "collect_deprecations returns the return value of the block and the deprecations collected" do
    result = collect_deprecations(@deprecator) do
      @deprecator.warn
      :result
    end
    assert_equal 2, result.size
    assert_equal :result, result.first
    assert_match "DEPRECATION WARNING:", result.last.sole
  end

  test "collect_deprecations requires a deprecator" do
    assert_raises(ArgumentError) do
      collect_deprecations { }
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

  test "Module::deprecate requires a deprecator" do
    klass = Class.new(Deprecatee)
    assert_raises(ArgumentError) do
      klass.deprecate :zero
    end
  end

  test "DeprecatedObjectProxy" do
    deprecated_object = ActiveSupport::Deprecation::DeprecatedObjectProxy.new(Object.new, ":bomb:", @deprecator)
    assert_deprecated(/:bomb:/, @deprecator) { deprecated_object.to_s }
  end

  test "DeprecatedObjectProxy requires a deprecator" do
    assert_raises(ArgumentError) do
      ActiveSupport::Deprecation::DeprecatedObjectProxy.new(Object.new, ":bomb:")
    end
  end

  test "nil behavior is ignored" do
    @deprecator.behavior = nil
    assert_deprecated("fubar", @deprecator) { @deprecator.warn("fubar") }
  end

  test "behavior callbacks" do
    assert_callbacks_called_with(deprecator: @deprecator, message: /fubar/) do |callbacks|
      @deprecator.behavior = callbacks
      @deprecator.warn("fubar")
    end
  end

  test "behavior callbacks with callable objects" do
    assert_callbacks_called_with(deprecator: @deprecator, message: /fubar/) do |callbacks|
      callbacks.select!(&:lambda?)
      assert_not_empty callbacks

      @deprecator.behavior = callbacks.map do |callback|
        Object.new.tap { |object| object.define_singleton_method(:call, &callback) }
      end
      @deprecator.warn("fubar")
    end
  end

  test ":raise behavior" do
    @deprecator.behavior = :raise

    message   = "Revise this deprecated stuff now!"
    callstack = caller_locations

    e = assert_raise ActiveSupport::DeprecationException do
      @deprecator.behavior.first.call(message, callstack, @deprecator)
    end
    assert_equal message, e.message
    assert_equal callstack.map(&:to_s), e.backtrace.map(&:to_s)
  end

  test ":stderr behavior" do
    @deprecator.behavior = :stderr
    behavior = @deprecator.behavior.first

    output = capture(:stderr) do
      behavior.call("Some error!", ["call stack!"], @deprecator)
    end

    assert_match "Some error!", output
    assert_no_match "call stack!", output
  end

  test ":stderr behavior with debug" do
    @deprecator.behavior = :stderr
    behavior = @deprecator.behavior.first
    @deprecator.debug = true

    output = capture(:stderr) do
      behavior.call("Some error!", ["call stack!"], @deprecator)
    end

    assert_match "Some error!", output
    assert_match "call stack!", output
  end

  class CallerLocation
    attr_reader :path, :lineno, :label
    alias_method :absolute_path, :path

    def initialize(label, lineno)
      @path = __FILE__
      @lineno = lineno
      @label = label
    end
  end

  test ":stderr behavior with #warn" do
    @deprecator.behavior = :stderr

    output = capture(:stderr) do
      @deprecator.warn("Instance error!", [CallerLocation.new("instance call stack!", __LINE__)])
    end

    assert_match(/Instance error!/, output)
    assert_match(/instance call stack!/, output)
  end

  test ":log behavior" do
    @deprecator.behavior = :log
    output = StringIO.new

    with_rails_logger(Logger.new(output)) do
      @deprecator.behavior.first.call("fubar", ["call stack!"], @deprecator)
    end

    assert_match "fubar", output.string
    assert_no_match "call stack!", output.string
  end

  test ":log behavior with debug" do
    @deprecator.behavior = :log
    @deprecator.debug = true
    output = StringIO.new

    with_rails_logger(Logger.new(output)) do
      @deprecator.behavior.first.call("fubar", ["call stack!"], @deprecator)
    end

    assert_match "fubar", output.string
    assert_match "call stack!", output.string
  end

  test ":log behavior without Rails.logger" do
    @deprecator.behavior = :log

    output = capture(:stderr) do
      with_rails_logger(nil) do
        @deprecator.behavior.first.call("fubar", ["call stack!"], @deprecator)
      end
    end

    assert_match "fubar", output
  end

  test ":silence behavior" do
    @deprecator.behavior = :silence
    behavior = @deprecator.behavior.first

    output = capture(:stderr) do
      behavior.call("Some error!", ["call stack!"], @deprecator)
    end

    assert_empty output
  end

  test ":notify behavior" do
    @deprecator = ActiveSupport::Deprecation.new("horizon", "MyGem::Custom")
    @deprecator.behavior = :notify
    behavior = @deprecator.behavior.first

    expected_payload = {
      message: "Some error!",
      callstack: ["call stack!"],
      deprecation_horizon: "horizon",
      gem_name: "MyGem::Custom"
    }

    assert_notifications_count("deprecation.my_gem_custom", 1) do
      assert_notification("deprecation.my_gem_custom", expected_payload) do
        behavior.call("Some error!", ["call stack!"], @deprecator)
      end
    end
  end

  test ":report_error behavior" do
    @deprecator = ActiveSupport::Deprecation.new("horizon", "MyGem::Custom")
    @deprecator.behavior = :report
    report = assert_error_reported(ActiveSupport::DeprecationException) do
      @deprecator.warn
    end
    assert_equal true, report.handled
    assert_equal :warning, report.severity
    assert_equal "application", report.source
  end

  test "invalid behavior" do
    e = assert_raises(ArgumentError) do
      @deprecator.behavior = :invalid
    end

    assert_equal ":invalid is not a valid deprecation behavior.", e.message
  end

  test "DeprecatedInstanceVariableProxy" do
    instance = Deprecatee.new
    instance.fubar = ActiveSupport::Deprecation::DeprecatedInstanceVariableProxy.new(instance, :foo_bar, "@fubar", deprecator: @deprecator)
    instance.foo_bar = "foo bar!"

    fubar_size = assert_deprecated("@fubar.size", @deprecator) { instance.fubar.size }
    assert_equal instance.foo_bar.size, fubar_size

    fubar_s = assert_deprecated("@fubar.to_s", @deprecator) { instance.fubar.to_s }
    assert_equal instance.foo_bar.to_s, fubar_s
  end

  test "DeprecatedInstanceVariableProxy does not warn on inspect" do
    instance = Deprecatee.new
    instance.fubar = ActiveSupport::Deprecation::DeprecatedInstanceVariableProxy.new(instance, :foo_bar, "@fubar", deprecator: @deprecator)
    instance.foo_bar = "foo bar!"

    fubar_inspected = assert_not_deprecated(@deprecator) { instance.fubar.inspect }
    assert_equal instance.foo_bar.inspect, fubar_inspected
  end

  test "DeprecatedInstanceVariableProxy requires a deprecator" do
    assert_raises(ArgumentError) do
      ActiveSupport::Deprecation::DeprecatedInstanceVariableProxy.new(Deprecatee.new, :foobar, "@fubar")
    end
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

  test "DeprecatedConstantProxy requires a deprecator" do
    assert_raise(ArgumentError) do
      ActiveSupport::Deprecation::DeprecatedConstantProxy.new("Fuu", "Undeprecated::Foo")
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

  test "deprecate_constant requires a deprecator" do
    legacy = Module.new.include(ActiveSupport::Deprecation::DeprecatedConstantAccessor)
    assert_raises(ArgumentError) do
      legacy.deprecate_constant "OLD", "NEW"
    end
  end

  test "assert_deprecated raises when no deprecation warning" do
    assert_raises(Minitest::Assertion) do
      assert_deprecated(@deprecator) { 1 + 1 }
    end
  end

  test "assert_not_deprecated raises when some deprecation warning" do
    assert_raises(Minitest::Assertion) do
      assert_not_deprecated(@deprecator) { @deprecator.warn }
    end
  end

  test "assert_deprecated without match argument" do
    assert_deprecated(@deprecator) do
      @deprecator.warn
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

  test "assert_not_deprecated returns the result of the block" do
    assert_equal 123, assert_not_deprecated(@deprecator) { 123 }
  end

  test "assert_deprecated returns the result of the block" do
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

    assert_deprecated(@deprecator) { @deprecator.warn }

    @deprecator.silenced = true
    assert @deprecator.silenced

    assert_not_deprecated(@deprecator) { @deprecator.warn }
  end

  test "silence returns the result of the block" do
    assert_equal 123, @deprecator.silence { 123 }
  end

  test "silence ensures silencing is reverted after an error is raised" do
    assert_raises do
      @deprecator.silence { raise }
    end

    assert_deprecated(@deprecator) { @deprecator.warn }
  end

  test "silence only affects the current thread" do
    @deprecator.silence do
      assert_not_deprecated(@deprecator) { @deprecator.warn }

      Thread.new do
        assert_deprecated(@deprecator) { @deprecator.warn }

        @deprecator.silence do
          assert_not_deprecated(@deprecator) { @deprecator.warn }
        end

        assert_deprecated(@deprecator) { @deprecator.warn }
      end.join

      assert_not_deprecated(@deprecator) { @deprecator.warn }
    end
  end

  test "Module::deprecate with method name only" do
    klass = Class.new(Deprecatee)
    klass.deprecate :fubar, :fubar=, deprecator: @deprecator

    assert_deprecated(@deprecator) { klass.new.fubar }
    assert_deprecated(@deprecator) { klass.new.fubar = :foo }
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
    assert_equal [], @deprecator.disallowed_warnings
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
    @deprecator.disallowed_warnings = :all
    @deprecator.behavior = proc { flunk }

    assert_disallowed(/fubar/, @deprecator) do
      @deprecator.warn("using fubar is deprecated")
    end
  end

  test "disallowed_warnings with the default warning message" do
    @deprecator.disallowed_warnings = :all
    assert_disallowed(@deprecator) { @deprecator.warn }

    @deprecator.disallowed_warnings = ["fubar"]
    assert_deprecated(@deprecator) { @deprecator.warn }
  end

  test "disallowed_behavior callbacks" do
    assert_callbacks_called_with(deprecator: @deprecator, message: /fubar/) do |callbacks|
      @deprecator.disallowed_behavior = callbacks
      @deprecator.disallowed_warnings = ["fubar"]
      @deprecator.warn("fubar")
    end
  end

  test "allow" do
    @deprecator.disallowed_warnings = :all

    assert_disallowed(@deprecator) { @deprecator.warn }

    @deprecator.allow do
      assert_deprecated(@deprecator) { @deprecator.warn }
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
      assert_deprecated(@deprecator) { @deprecator.warn }
    end

    assert_disallowed(@deprecator) { @deprecator.warn }
  end

  test "allow only affects the current thread" do
    @deprecator.disallowed_warnings = :all

    @deprecator.allow do
      assert_deprecated(@deprecator) { @deprecator.warn }

      Thread.new do
        assert_disallowed(@deprecator) { @deprecator.warn }

        @deprecator.allow do
          assert_deprecated(@deprecator) { @deprecator.warn }
        end

        assert_disallowed(@deprecator) { @deprecator.warn }
      end.join

      assert_deprecated(@deprecator) { @deprecator.warn }
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
      assert_deprecated(@deprecator) { @deprecator.warn }
    end

    @deprecator.allow(["fubar"]) do
      assert_disallowed(@deprecator) { @deprecator.warn }
    end
  end

  test "warn deprecation skips the internal caller locations" do
    @deprecator.behavior = ->(_, callstack, *) { @callstack = callstack }
    method_that_emits_deprecation(@deprecator)
    assert_equal File.expand_path(__FILE__), @callstack.first.absolute_path
    assert_equal __LINE__ - 2, @callstack.first.lineno
  end

  class_eval(<<~RUBY, "/path/to/template.html.erb", 1)
    def generated_method_that_call_deprecation(deprecator)
      deprecator.warn("Here", caller_locations(0, 10))
    end
  RUBY

  test "warn deprecation can blame code generated with eval" do
    @deprecator.behavior = ->(message, *) { @message = message }
    generated_method_that_call_deprecation(@deprecator)
    if RUBY_VERSION >= "3.4"
      assert_equal "DEPRECATION WARNING: Here (called from DeprecationTest#generated_method_that_call_deprecation at /path/to/template.html.erb:2)", @message
    else
      assert_equal "DEPRECATION WARNING: Here (called from generated_method_that_call_deprecation at /path/to/template.html.erb:2)", @message
    end
  end

  test "warn deprecation can blame code from internal methods" do
    @deprecator.behavior = ->(message, *) { @message = message }
    method_that_emits_deprecation_with_internal_method(@deprecator)

    assert_includes(@message, "/path/to/user/code.rb")
  end

  class_eval(<<~RUBY, "/path/to/user/code.rb", 1)
    def method_that_emits_deprecation_with_internal_method(deprecator)
      [1].each { deprecator.warn }
    end
  RUBY

  private
    def method_that_emits_deprecation(deprecator)
      deprecator.warn
    end

    def with_rails_application_deprecators(&block)
      application = Struct.new(:deprecators).new(ActiveSupport::Deprecation::Deprecators.new)
      rails = Struct.new(:application).new(application)
      rails.application.deprecators[:deprecator] = @deprecator
      stub_const(Object, :Rails, rails, &block)
    end

    def deprecator_with_messages
      klass = Class.new(ActiveSupport::Deprecation)
      deprecator = klass.new
      deprecator.behavior = Proc.new { |message, callstack| deprecator.messages << message }
      def deprecator.messages
        @messages ||= []
      end
      deprecator
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
      deprecator ||= ActiveSupport::Deprecation
      original_disallowed_behavior = deprecator.disallowed_behavior
      disallowed = []
      deprecator.disallowed_behavior = proc { |message| disallowed << message }
      result = yield
      [result, disallowed]
    ensure
      deprecator.disallowed_behavior = original_disallowed_behavior
    end

    # a la assert_deprecated
    def assert_disallowed(match = nil, deprecator = nil, &block)
      match, deprecator = nil, match if match.is_a?(ActiveSupport::Deprecation)
      result, disallowed = collect_disallowed(deprecator, &block)
      assert_not_empty disallowed, "Expected a disallowed deprecation within the block but received none"
      if match
        match = Regexp.new(Regexp.escape(match)) unless match.is_a?(Regexp)
        assert disallowed.any?(match), "No disallowed deprecations matched #{match}: #{disallowed.inspect}"
      end
      result
    end

    def assert_callbacks_called_with(matchers = {})
      matchers[:message] ||= String
      matchers[:callstack] ||= Array
      matchers[:deprecator]&.tap do |deprecator|
        matchers[:deprecation_horizon] ||= deprecator.deprecation_horizon
        matchers[:gem_name] ||= deprecator.gem_name
      end

      bindings = []

      callbacks = [
        lambda { |message, callstack, deprecator| bindings << binding },
        proc   { |message, callstack, deprecator| bindings << binding },
        lambda { |message, callstack, deprecation_horizon, gem_name| bindings << binding },
        proc   { |message, callstack, deprecation_horizon, gem_name| bindings << binding },
        lambda { |message, callstack| bindings << binding },
        proc   { |message, callstack| bindings << binding },
        proc   { |message| bindings << binding },
        proc   { bindings << binding },

        lambda do |*args|
          message, callstack, deprecator = args
          bindings << binding
          [message, callstack, deprecator]
        end,

        lambda do |message, *other|
          callstack, deprecator = other
          bindings << binding
          [callstack, deprecator]
        end,

        lambda do |message, callstack, *details|
          deprecation_horizon, gem_name = details
          bindings << binding
          [deprecation_horizon, gem_name]
        end,
      ]

      yield callbacks

      assert_equal callbacks.size, bindings.size

      bindings.each do |bound|
        matchers.each do |name, matcher|
          if bound.local_variable_defined?(name)
            assert_operator matcher, :===, bound.local_variable_get(name),
              "Unexpected #{name} in callback defined at #{bound.source_location.join(":")}"
          end
        end
      end
    end
end
