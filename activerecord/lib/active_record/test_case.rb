require 'active_support/deprecation'
require 'active_support/test_case'

ActiveSupport::Deprecation.warn('ActiveRecord::TestCase is deprecated, please use ActiveSupport::TestCase')
module ActiveRecord
  # = Active Record Test Case
  #
  # Defines some test assertions to test against SQL queries.
  class TestCase < ActiveSupport::TestCase #:nodoc:
    setup :cleanup_identity_map

    def setup
      cleanup_identity_map
    end

    def teardown
      ActiveRecord::SQLCounter.log.clear
    end

    def cleanup_identity_map
      ActiveRecord::IdentityMap.clear
    end

    def assert_date_from_db(expected, actual, message = nil)
      # SybaseAdapter doesn't have a separate column type just for dates,
      # so the time is in the string and incorrectly formatted
      if current_adapter?(:SybaseAdapter)
        assert_equal expected.to_s, actual.to_date.to_s, message
      else
        assert_equal expected.to_s, actual.to_s, message
      end
    end
  end
end
