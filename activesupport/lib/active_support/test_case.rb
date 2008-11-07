require 'active_support/testing/setup_and_teardown'
require 'active_support/testing/assertions'
require 'active_support/testing/declarative'

module ActiveSupport
  # Prefer MiniTest with Test::Unit compatibility.
  begin
    require 'minitest/unit'

    # Hack around the test/unit autorun.
    autorun_enabled = MiniTest::Unit.class_variable_get('@@installed_at_exit')
    MiniTest::Unit.disable_autorun
    require 'test/unit'
    MiniTest::Unit.class_variable_set('@@installed_at_exit', autorun_enabled)

    class TestCase < ::Test::Unit::TestCase
      Assertion = MiniTest::Assertion
    end

  # Test::Unit compatibility.
  rescue LoadError
    require 'test/unit/testcase'
    require 'active_support/testing/default'

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
