require "cases/helper"
require 'models/default'

module ActiveRecord
  module ConnectionAdapters
    module Quoting
      class QuotingTest < ActiveRecord::TestCase
        def test_quoting_relation
          relation = Default.select('id').where('id > ?', 0)
          assert_equal "(SELECT id FROM \"defaults\"  WHERE (id > 0))",
            AbstractAdapter.new(nil).quote(relation)
        end

        def test_quoting_classes
          assert_equal "'Object'", AbstractAdapter.new(nil).quote(Object)
        end
      end
    end
  end
end
