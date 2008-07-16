require 'active_support/testing/core_ext/test/unit/assertions'
require 'active_support/testing/setup_and_teardown'

class Test::Unit::TestCase #:nodoc:
  include ActiveSupport::Testing::SetupAndTeardown
end