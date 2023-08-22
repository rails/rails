# frozen_string_literal: true

require "abstract_unit"

module ActionDispatch
  class ExceptionWrapperTest < ActionDispatch::IntegrationTest
    class TestError < StandardError
    end

    class TopErrorProxy < StandardError
      def initialize(ex, n)
        @ex = ex
        @n  = n
      end

      def backtrace
        @ex.backtrace.first(@n)
      end

      def backtrace_locations
        @ex.backtrace_locations.first(@n)
      end
    end

    class BadlyDefinedError < StandardError
      def backtrace
        nil
      end
    end

    setup do
      @cleaner = ActiveSupport::BacktraceCleaner.new
      @cleaner.remove_filters!
      @cleaner.add_silencer { |line| !line.start_with?("lib") }
    end

    class_eval "def index; raise TestError; end", "lib/file.rb", 42

    test "#source_extracts fetches source fragments for every backtrace entry" do
      exception = begin index; rescue TestError => ex; ex; end
      wrapper = ExceptionWrapper.new(nil, TopErrorProxy.new(exception, 1))

      assert_called_with(wrapper, :source_fragment, ["lib/file.rb", 42], returns: "foo") do
        assert_equal [ code: "foo", line_number: 42 ], wrapper.source_extracts
      end
    end

    class_eval "def ms_index; raise TestError; end", "c:/path/to/rails/app/controller.rb", 27

    test "#source_extracts works with Windows paths" do
      exc = begin ms_index; rescue TestError => ex; ex; end

      wrapper = ExceptionWrapper.new(nil, TopErrorProxy.new(exc, 1))

      assert_called_with(wrapper, :source_fragment, ["c:/path/to/rails/app/controller.rb", 27], returns: "nothing") do
        assert_equal [ code: "nothing", line_number: 27 ], wrapper.source_extracts
      end
    end

    class_eval "def invalid_ex; raise TestError; end", "invalid", 0

    test "#source_extracts works with non standard backtrace" do
      exc = begin invalid_ex; rescue TestError => ex; ex; end

      wrapper = ExceptionWrapper.new(nil, TopErrorProxy.new(exc, 1))

      assert_called_with(wrapper, :source_fragment, ["invalid", 0], returns: "nothing") do
        assert_equal [ code: "nothing", line_number: 0 ], wrapper.source_extracts
      end
    end

    if defined?(ErrorHighlight) && Gem::Version.new(ErrorHighlight::VERSION) >= Gem::Version.new("0.4.0")
      test "#source_extracts works with error_highlight" do
        lineno = __LINE__
        begin
          1.time
        rescue NameError => exc
        end

        wrapper = ExceptionWrapper.new(nil, exc)

        code = {}
        File.foreach(__FILE__).to_a.drop(lineno - 1).take(6).each_with_index do |line, i|
          code[lineno + i] = line
        end
        code[lineno + 2] = ["          1", ".time", "\n"]
        assert_equal({ code: code, line_number: lineno + 2 }, wrapper.source_extracts.first)
      end
    end

    test "#application_trace returns traces only from the application" do
      exception = begin index; rescue TestError => ex; ex; end
      wrapper = ExceptionWrapper.new(@cleaner, TopErrorProxy.new(exception, 1))

      assert_equal [ "lib/file.rb:42:in `index'" ], wrapper.application_trace.map(&:to_s)
    end

    test "#status_code returns 400 for Rack::Utils::ParameterTypeError" do
      exception = Rack::Utils::ParameterTypeError.new
      wrapper = ExceptionWrapper.new(@cleaner, exception)
      assert_equal 400, wrapper.status_code
    end

    test "#rescue_response? returns false for an exception that's not in rescue_responses" do
      exception = RuntimeError.new
      wrapper = ExceptionWrapper.new(@cleaner, exception)
      assert_equal false, wrapper.rescue_response?
    end

    test "#rescue_response? returns true for an exception that is in rescue_responses" do
      exception = ActionController::RoutingError.new("")
      wrapper = ExceptionWrapper.new(@cleaner, exception)
      assert_equal true, wrapper.rescue_response?
    end

    test "#application_trace cannot be nil" do
      nil_backtrace_wrapper = ExceptionWrapper.new(@cleaner, BadlyDefinedError.new)
      nil_cleaner_wrapper = ExceptionWrapper.new(nil, BadlyDefinedError.new)

      assert_equal [], nil_backtrace_wrapper.application_trace
      assert_equal [], nil_cleaner_wrapper.application_trace
    end

    test "#framework_trace returns traces outside the application" do
      exception = begin index; rescue TestError => ex; ex; end
      wrapper = ExceptionWrapper.new(@cleaner, exception)

      # The exception gets one more frame for the `begin`.  It's hard to
      # get a stack trace exactly the same, so just drop that frame and
      # make sure the rest are OK
      assert_equal caller, wrapper.framework_trace.drop(1).map(&:to_s)
    end

    test "#framework_trace cannot be nil" do
      nil_backtrace_wrapper = ExceptionWrapper.new(@cleaner, BadlyDefinedError.new)
      nil_cleaner_wrapper = ExceptionWrapper.new(nil, BadlyDefinedError.new)

      assert_equal [], nil_backtrace_wrapper.framework_trace
      assert_equal [], nil_cleaner_wrapper.framework_trace
    end

    test "#full_trace returns application and framework traces" do
      exception = begin index; rescue TestError => ex; ex; end
      wrapper = ExceptionWrapper.new(@cleaner, exception)

      assert_equal exception.backtrace, wrapper.full_trace.map(&:to_s)
    end

    test "#full_trace cannot be nil" do
      nil_backtrace_wrapper = ExceptionWrapper.new(@cleaner, BadlyDefinedError.new)
      nil_cleaner_wrapper = ExceptionWrapper.new(nil, BadlyDefinedError.new)

      assert_equal [], nil_backtrace_wrapper.full_trace
      assert_equal [], nil_cleaner_wrapper.full_trace
    end

    class_eval "def in_rack; index; end", "/gems/rack.rb", 43

    test "#traces returns every trace by category enumerated with an index" do
      exception = begin in_rack; rescue TestError => ex; TopErrorProxy.new(ex, 2); end
      wrapper = ExceptionWrapper.new(@cleaner, exception)

      assert_equal({
        "Application Trace" => [
          exception_object_id: exception.object_id,
          id: 0,
          trace: "lib/file.rb:42:in `index'"
        ],
        "Framework Trace" => [
          exception_object_id: exception.object_id,
          id: 1,
          trace: "/gems/rack.rb:43:in `in_rack'"
        ],
        "Full Trace" => [
          {
            exception_object_id: exception.object_id,
            id: 0,
            trace: "lib/file.rb:42:in `index'"
          },
          {
            exception_object_id: exception.object_id,
            id: 1,
            trace: "/gems/rack.rb:43:in `in_rack'"
          }
        ]
      }.inspect, wrapper.traces.inspect)
    end

    test "#show? returns false when using :rescuable and the exceptions is not rescuable" do
      exception = RuntimeError.new("")
      wrapper = ExceptionWrapper.new(nil, exception)

      env = { "action_dispatch.show_exceptions" => :rescuable }
      request = ActionDispatch::Request.new(env)

      assert_equal false, wrapper.show?(request)
    end

    test "#show? returns true when using :rescuable and the exceptions is rescuable" do
      exception = AbstractController::ActionNotFound.new("")
      wrapper = ExceptionWrapper.new(nil, exception)

      env = { "action_dispatch.show_exceptions" => :rescuable }
      request = ActionDispatch::Request.new(env)

      assert_equal true, wrapper.show?(request)
    end

    test "#show? returns false when using :none and the exceptions is rescuable" do
      exception = AbstractController::ActionNotFound.new("")
      wrapper = ExceptionWrapper.new(nil, exception)

      env = { "action_dispatch.show_exceptions" => :none }
      request = ActionDispatch::Request.new(env)

      assert_equal false, wrapper.show?(request)
    end

    test "#show? returns true when using :all and the exceptions is not rescuable" do
      exception = RuntimeError.new("")
      wrapper = ExceptionWrapper.new(nil, exception)

      env = { "action_dispatch.show_exceptions" => :all }
      request = ActionDispatch::Request.new(env)

      assert_equal true, wrapper.show?(request)
    end

    test "#show? emits a deprecation when show_exceptions is true" do
      exception = RuntimeError.new("")
      wrapper = ExceptionWrapper.new(nil, exception)

      env = { "action_dispatch.show_exceptions" => true }
      request = ActionDispatch::Request.new(env)

      msg = "Setting action_dispatch.show_exceptions to true is deprecated. Set to :all instead."
      result = assert_deprecated(msg, ActionDispatch.deprecator) do
        wrapper.show?(request)
      end

      assert_equal true, result
    end

    test "#show? emits a deprecation when show_exceptions is false" do
      exception = RuntimeError.new("")
      wrapper = ExceptionWrapper.new(nil, exception)

      env = { "action_dispatch.show_exceptions" => false }
      request = ActionDispatch::Request.new(env)

      msg = "Setting action_dispatch.show_exceptions to false is deprecated. Set to :none instead."
      result = assert_deprecated(msg, ActionDispatch.deprecator) do
        wrapper.show?(request)
      end

      assert_equal false, result
    end
  end
end
