require 'abstract_unit'

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
      Rails.stubs(:root).returns(Pathname.new('.'))

      cleaner = ActiveSupport::BacktraceCleaner.new
      cleaner.add_silencer { |line| line !~ /^lib/ }

      @environment = { 'action_dispatch.backtrace_cleaner' => cleaner }
    end

    test '#source_extracts fetches source fragments for every backtrace entry' do
      exception = TestError.new("lib/file.rb:42:in `index'")
      wrapper = ExceptionWrapper.new({}, exception)

      wrapper.expects(:source_fragment).with('lib/file.rb', 42).returns('foo')

      assert_equal [ code: 'foo', line_number: 42 ], wrapper.source_extracts
    end


    test '#application_trace returns traces only from the application' do
      exception = TestError.new(caller.prepend("lib/file.rb:42:in `index'"))
      wrapper = ExceptionWrapper.new(@environment, exception)

      assert_equal [ "lib/file.rb:42:in `index'" ], wrapper.application_trace
    end

    test '#application_trace cannot be nil' do
      nil_backtrace_wrapper = ExceptionWrapper.new(@environment, BadlyDefinedError.new)
      nil_cleaner_wrapper = ExceptionWrapper.new({}, BadlyDefinedError.new)

      assert_equal [], nil_backtrace_wrapper.application_trace
      assert_equal [], nil_cleaner_wrapper.application_trace
    end

    test '#framework_trace returns traces outside the application' do
      exception = TestError.new(caller.prepend("lib/file.rb:42:in `index'"))
      wrapper = ExceptionWrapper.new(@environment, exception)

      assert_equal caller, wrapper.framework_trace
    end

    test '#framework_trace cannot be nil' do
      nil_backtrace_wrapper = ExceptionWrapper.new(@environment, BadlyDefinedError.new)
      nil_cleaner_wrapper = ExceptionWrapper.new({}, BadlyDefinedError.new)

      assert_equal [], nil_backtrace_wrapper.framework_trace
      assert_equal [], nil_cleaner_wrapper.framework_trace
    end

    test '#full_trace returns application and framework traces' do
      exception = TestError.new(caller.prepend("lib/file.rb:42:in `index'"))
      wrapper = ExceptionWrapper.new(@environment, exception)

      assert_equal exception.backtrace, wrapper.full_trace
    end

    test '#full_trace cannot be nil' do
      nil_backtrace_wrapper = ExceptionWrapper.new(@environment, BadlyDefinedError.new)
      nil_cleaner_wrapper = ExceptionWrapper.new({}, BadlyDefinedError.new)

      assert_equal [], nil_backtrace_wrapper.full_trace
      assert_equal [], nil_cleaner_wrapper.full_trace
    end

    test '#traces returns every trace by category enumerated with an index' do
      exception = TestError.new("lib/file.rb:42:in `index'", "/gems/rack.rb:43:in `index'")
      wrapper = ExceptionWrapper.new(@environment, exception)

      assert_equal({
        'Application Trace' => [ id: 0, trace: "lib/file.rb:42:in `index'" ],
        'Framework Trace' => [ id: 1, trace: "/gems/rack.rb:43:in `index'" ],
        'Full Trace' => [
          { id: 0, trace: "lib/file.rb:42:in `index'" },
          { id: 1, trace: "/gems/rack.rb:43:in `index'" }
        ]
      }, wrapper.traces)
    end
  end
end
