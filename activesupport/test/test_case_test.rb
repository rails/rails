require 'abstract_unit'

module ActiveSupport
  class TestCaseTest < ActiveSupport::TestCase
    def test_pending_deprecation
      assert_deprecated do
        pending "should use #skip instead"
      end
    end
  end
end
