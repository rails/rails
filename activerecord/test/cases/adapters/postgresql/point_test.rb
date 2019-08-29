# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      class PointTest < ActiveRecord::PostgreSQLTestCase
        def setup
          @type = OID::Point.new
        end

        def test_valid_user_input_cast
          assert_equal(ActiveRecord::Point.new(3.4, 5.6), @type.cast("3.4, 5.6"))
          assert_equal(ActiveRecord::Point.new(3.4, 5.6), @type.cast("(3.4, 5.6)"))
        end

        def test_invalid_user_input_cast
          assert_nil @type.cast("   ")
          assert_nil @type.cast("3,")
        end

        def test_float_array_cast
          assert_equal(ActiveRecord::Point.new(3.4, 5.6), @type.cast([3.4, 5.6]))
        end

        def test_invalid_subtype_array_cast
          assert_nil @type.cast([true, "a"])
        end

        def test_unsupported_type_cast
          assert_equal(4, @type.cast(4))
          assert_equal(true, @type.cast(true))
        end
      end
    end
  end
end
