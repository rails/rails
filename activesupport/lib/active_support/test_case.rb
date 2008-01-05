require 'test/unit/testcase'
require 'active_support/testing/setup_and_teardown'
require 'active_support/testing/default'

# TODO: move to core_ext
class Test::Unit::TestCase #:nodoc:
  include ActiveSupport::Testing::SetupAndTeardown
end

module ActiveSupport
  class TestCase < Test::Unit::TestCase
  end
end
