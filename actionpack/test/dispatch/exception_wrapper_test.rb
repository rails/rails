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

    class TestTemplate
      attr_reader :method_name

      def initialize(method_name)
        @method_name = method_name
      end

      def spot(backtrace_location)
        { first_lineno: 1, script_lines: ["compiled @ #{backtrace_location.base_label}:#{backtrace_location.lineno}"] }
      end

      def translate_location(backtrace_location, spot)
        # note: extract_source_fragment_lines pulls lines from script_lines for indexes near first_lineno
        # since we're mocking the behavior, we need to leave the first_lineno close to 1
        { first_lineno: 1, script_lines: ["translated @ #{backtrace_location.base_label}:#{backtrace_location.lineno}"] }
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

    class_eval "def throw_syntax_error; eval %(
      pluralize { # create a syntax error without a parser warning
    ); end", "lib/file.rb", 42

    test "#source_extracts works with eval syntax error" do
      exception = begin throw_syntax_error; rescue SyntaxError => ex; ex; end

      wrapper = ExceptionWrapper.new(nil, TopErrorProxy.new(exception, 1))

      assert_called_with(wrapper, :source_fragment, ["lib/file.rb", 42], returns: "foo") do
        assert_equal [ code: "foo", line_number: 42 ], wrapper.source_extracts
      end
    end

    test "#source_extracts works with nil backtrace_locations" do
      exception = begin eval "class Foo; yield; end"; rescue SyntaxError => ex; ex; end

      wrapper = ExceptionWrapper.new(nil, exception)

      assert_empty wrapper.source_extracts
    end

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
      code[lineno + 2] = ["        1", ".time", "\n"]
      assert_equal({ code: code, line_number: lineno + 2 }, wrapper.source_extracts.first)
    end

    class_eval "def _app_views_tests_show_html_erb;
      raise TestError; end", "app/views/tests/show.html.erb", 2

    test "#source_extracts wraps template lines in a SourceMapLocation" do
      exception = begin _app_views_tests_show_html_erb; rescue TestError => ex; ex; end

      template = TestTemplate.new("_app_views_tests_show_html_erb")
      resolver = Data.define(:built_templates).new(built_templates: [template])

      wrapper = nil
      assert_called(ActionView::PathRegistry, :all_resolvers, nil, returns: [resolver]) do
        wrapper = ExceptionWrapper.new(nil, TopErrorProxy.new(exception, 1))
      end

      assert_equal [{
        code: { 1 => "translated @ _app_views_tests_show_html_erb:3" },
        line_number: 1
      }], wrapper.source_extracts
    end

    class_eval "def _app_views_tests_nested_html_erb;
      [1].each do
        [2].each do
          raise TestError
        end
      end
    end", "app/views/tests/nested.html.erb", 2

    test "#source_extracts works with nested template code" do
      exception = begin _app_views_tests_nested_html_erb; rescue TestError => ex; ex; end

      template = TestTemplate.new("_app_views_tests_nested_html_erb")
      resolver = Data.define(:built_templates).new(built_templates: [template])

      wrapper = nil
      assert_called(ActionView::PathRegistry, :all_resolvers, nil, returns: [resolver]) do
        wrapper = ExceptionWrapper.new(nil, TopErrorProxy.new(exception, 5))
      end

      extracts = wrapper.source_extracts
      assert_equal({
        code: { 1 => "translated @ _app_views_tests_nested_html_erb:5" },
        line_number: 1
      }, extracts[0])
      # extracts[1] is Array#each (unreliable backtrace across rubies)
      assert_equal({
        code: { 1 => "translated @ _app_views_tests_nested_html_erb:4" },
        line_number: 1
      }, extracts[2])
      # extracts[3] is Array#each (unreliable backtrace across rubies)
      assert_equal({
        code: { 1 => "translated @ _app_views_tests_nested_html_erb:3" },
        line_number: 1
      }, extracts[4])
    end

    test "#application_trace returns traces only from the application" do
      exception = begin index; rescue TestError => ex; ex; end
      wrapper = ExceptionWrapper.new(@cleaner, TopErrorProxy.new(exception, 1))

      if RUBY_VERSION >= "3.4"
        assert_equal [ "lib/file.rb:42:in 'ActionDispatch::ExceptionWrapperTest#index'" ], wrapper.application_trace.map(&:to_s)
      else
        assert_equal [ "lib/file.rb:42:in `index'" ], wrapper.application_trace.map(&:to_s)
      end
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

      if RUBY_VERSION >= "3.4"
        assert_equal({
          "Application Trace" => [
            exception_object_id: exception.object_id,
            id: 0,
            trace: "lib/file.rb:42:in 'ActionDispatch::ExceptionWrapperTest#index'"
          ],
          "Framework Trace" => [
            exception_object_id: exception.object_id,
            id: 1,
            trace: "/gems/rack.rb:43:in 'ActionDispatch::ExceptionWrapperTest#in_rack'"
          ],
          "Full Trace" => [
            {
              exception_object_id: exception.object_id,
              id: 0,
              trace: "lib/file.rb:42:in 'ActionDispatch::ExceptionWrapperTest#index'"
            },
            {
              exception_object_id: exception.object_id,
              id: 1,
              trace: "/gems/rack.rb:43:in 'ActionDispatch::ExceptionWrapperTest#in_rack'"
            }
          ]
        }.inspect, wrapper.traces.inspect)
      else
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
  end
end
