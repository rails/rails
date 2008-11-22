require 'active_support/testing/setup_and_teardown'
require 'active_support/testing/assertions'
require 'active_support/testing/declarative'

module ActiveSupport
  # Prefer MiniTest with Test::Unit compatibility.
  begin
    require 'minitest/unit'

    # Hack around the test/unit autorun.
    autorun_enabled = MiniTest::Unit.send(:class_variable_get, '@@installed_at_exit')
    if MiniTest::Unit.respond_to?(:disable_autorun)
      MiniTest::Unit.disable_autorun
    else
      MiniTest::Unit.send(:class_variable_set, '@@installed_at_exit', false)
    end
    require 'test/unit'
    MiniTest::Unit.send(:class_variable_set, '@@installed_at_exit', autorun_enabled)

    class TestCase < ::Test::Unit::TestCase
      Assertion = MiniTest::Assertion
    end

    # TODO: Figure out how to get the Rails::BacktraceFilter into minitest/unit
  # Test::Unit compatibility.
  rescue LoadError
    require 'test/unit/testcase'
    require 'active_support/testing/default'

    if defined?(Rails)
      require 'rails/backtrace_cleaner'
      Test::Unit::Util::BacktraceFilter.module_eval { include Rails::BacktraceFilterForTestUnit }
    end

    class TestCase < ::Test::Unit::TestCase
      Assertion = Test::Unit::AssertionFailedError
      include ActiveSupport::Testing::Default
    end    
  end

  class TestCase
    include ActiveSupport::Testing::SetupAndTeardown
    include ActiveSupport::Testing::Assertions
    extend ActiveSupport::Testing::Declarative
  end
end