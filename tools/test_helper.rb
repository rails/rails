# frozen_string_literal: true

require "megatest/autorun"
require_relative "strict_warnings"

require "active_support/testing/method_call_assertions"
require "active_support/testing/time_helpers"
require "active_support/core_ext/integer/time"

require "active_support/megatest/setup_and_teardown"

class RailsTestCase < Megatest::Test
  include ActiveSupport::Megatest::SetupAndTeardown
  include ActiveSupport::Testing::MethodCallAssertions
  include ActiveSupport::Testing::TimeHelpers

  def assert_mock mock, msg = nil
    assert mock.verify
  rescue MockExpectationError => e
    msg = message(msg) { e.message }
    flunk msg
  end
end

# TODO: require_relative "../../tools/test_common"
