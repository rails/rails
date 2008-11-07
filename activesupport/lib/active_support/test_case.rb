require 'active_support/testing/setup_and_teardown'
require 'active_support/testing/assertions'
require 'active_support/testing/declarative'

module ActiveSupport
  # Prefer MiniTest with Test::Unit compatibility.
  # Hacks around the test/unit autorun.
  begin
    require 'minitest/unit'
    MiniTest::Unit.disable_autorun
    require 'test/unit'

    class TestCase < ::Test::Unit::TestCase
      @@installed_at_exit = false
    end

  # Test::Unit compatibility.
  rescue LoadError
    require 'test/unit/testcase'
    require 'active_support/testing/default'

    class TestCase < ::Test::Unit::TestCase
      include ActiveSupport::Testing::Default
    end
  end

  class TestCase
    include ActiveSupport::Testing::SetupAndTeardown
    include ActiveSupport::Testing::Assertions
    extend ActiveSupport::Testing::Declarative
  end
end
