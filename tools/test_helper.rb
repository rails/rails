# frozen_string_literal: true

require "megatest/autorun"
require_relative "strict_warnings"

require "active_support/testing/method_call_assertions"
require "active_support/testing/time_helpers"
require "active_support/core_ext/integer/time"
require "active_support/testing/deprecation"
require "active_support/testing/notification_assertions"
require "active_support/testing/error_reporter_assertions"

class RailsTestCase < Megatest::Test
  include ActiveSupport::Testing::MethodCallAssertions
  include ActiveSupport::Testing::TimeHelpers
  include ActiveSupport::Testing::Deprecation
  include ActiveSupport::Testing::NotificationAssertions
  include ActiveSupport::Testing::ErrorReporterAssertions

  def assert_mock(mock, msg = nil)
    assert mock.verify
  rescue MockExpectationError => e
    msg = message(msg) { e.message }
    flunk msg
  end

  private
    def _assert_nothing_raised_or_warn(method, &block)
      @__m.safe_yield(method, &block)
    end
end

require_relative "../tools/test_common"
