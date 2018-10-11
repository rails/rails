# frozen_string_literal: true

require "abstract_unit"

module ActionDispatch
  class ExceptionWrapperTest < ActionDispatch::IntegrationTest
    class TestError < StandardError
      attr_reader :backtrace

      def initialize(*backtrace)
        @backtrace = backtrace.flatten
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
      @cleaner.add_silencer { |line| line !~ /^lib/ }
    end

    test "#source_extracts fetches source fragments for every backtrace entry" do
      exception = TestError.new("lib/file.rb:42:in `index'")
      wrapper = ExceptionWrapper.new(nil, exception)

      assert_called_with(wrapper, :source_fragment, ["lib/file.rb", 42], returns: "foo") do
        assert_equal [ code: "foo", line_number: 42 ], wrapper.source_extracts
      end
    end

    test "#source_extracts works with Windows paths" do
      exc = TestError.new("c:/path/to/rails/app/controller.rb:27:in 'index':")

      wrapper = ExceptionWrapper.new(nil, exc)

      assert_called_with(wrapper, :source_fragment, ["c:/path/to/rails/app/controller.rb", 27], returns: "nothing") do
        assert_equal [ code: "nothing", line_number: 27 ], wrapper.source_extracts
      end
    end

    test "#source_extracts works with non standard backtrace" do
      exc = TestError.new("invalid")

      wrapper = ExceptionWrapper.new(nil, exc)

      assert_called_with(wrapper, :source_fragment, ["invalid", 0], returns: "nothing") do
        assert_equal [ code: "nothing", line_number: 0 ], wrapper.source_extracts
      end
    end

    test "#application_trace returns traces only from the application" do
      exception = TestError.new(caller.prepend("lib/file.rb:42:in `index'"))
      wrapper = ExceptionWrapper.new(@cleaner, exception)

      assert_equal [ "lib/file.rb:42:in `index'" ], wrapper.application_trace
    end

    test "#status_code returns 400 for Rack::Utils::ParameterTypeError" do
      exception = Rack::Utils::ParameterTypeError.new
      wrapper = ExceptionWrapper.new(@cleaner, exception)
      assert_equal 400, wrapper.status_code
    end

    test "#application_trace cannot be nil" do
      nil_backtrace_wrapper = ExceptionWrapper.new(@cleaner, BadlyDefinedError.new)
      nil_cleaner_wrapper = ExceptionWrapper.new(nil, BadlyDefinedError.new)

      assert_equal [], nil_backtrace_wrapper.application_trace
      assert_equal [], nil_cleaner_wrapper.application_trace
    end

    test "#framework_trace returns traces outside the application" do
      exception = TestError.new(caller.prepend("lib/file.rb:42:in `index'"))
      wrapper = ExceptionWrapper.new(@cleaner, exception)

      assert_equal caller, wrapper.framework_trace
    end

    test "#framework_trace cannot be nil" do
      nil_backtrace_wrapper = ExceptionWrapper.new(@cleaner, BadlyDefinedError.new)
      nil_cleaner_wrapper = ExceptionWrapper.new(nil, BadlyDefinedError.new)

      assert_equal [], nil_backtrace_wrapper.framework_trace
      assert_equal [], nil_cleaner_wrapper.framework_trace
    end

    test "#full_trace returns application and framework traces" do
      exception = TestError.new(caller.prepend("lib/file.rb:42:in `index'"))
      wrapper = ExceptionWrapper.new(@cleaner, exception)

      assert_equal exception.backtrace, wrapper.full_trace
    end

    test "#full_trace cannot be nil" do
      nil_backtrace_wrapper = ExceptionWrapper.new(@cleaner, BadlyDefinedError.new)
      nil_cleaner_wrapper = ExceptionWrapper.new(nil, BadlyDefinedError.new)

      assert_equal [], nil_backtrace_wrapper.full_trace
      assert_equal [], nil_cleaner_wrapper.full_trace
    end

    test "#traces returns every trace by category enumerated with an index" do
      exception = TestError.new("lib/file.rb:42:in `index'", "/gems/rack.rb:43:in `index'")
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
          trace: "/gems/rack.rb:43:in `index'"
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
            trace: "/gems/rack.rb:43:in `index'"
          }
        ]
      }, wrapper.traces)
    end
  end
end
