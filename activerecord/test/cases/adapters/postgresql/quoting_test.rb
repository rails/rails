require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter
      class QuotingTest < ActiveRecord::PostgreSQLTestCase
        def setup
          @conn = ActiveRecord::Base.connection
        end

        def test_type_cast_true
          assert_equal "t", @conn.type_cast(true)
        end

        def test_type_cast_false
          assert_equal "f", @conn.type_cast(false)
        end

        def test_quote_float_nan
          nan = 0.0 / 0
          assert_equal "'NaN'", @conn.quote(nan)
        end

        def test_quote_float_infinity
          infinity = 1.0 / 0
          assert_equal "'Infinity'", @conn.quote(infinity)
        end

        def test_quote_range
          range = "1,2]'; SELECT * FROM users; --".."a"
          type = OID::Range.new(Type::Integer.new, :int8range)
          assert_equal "'[1,0]'", @conn.quote(type.serialize(range))
        end

        def test_quote_bit_string
          value = "'); SELECT * FROM users; /*\n01\n*/--"
          type = OID::Bit.new
          assert_nil @conn.quote(type.serialize(value))
        end
      end
    end
  end
end
