require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    module Quoting
      class QuotingTest < ActiveRecord::TestCase
        def test_quoting_classes
          assert_equal "'Object'", AbstractAdapter.new(nil).quote(Object)
        end
      end
    end
  end
end
