require "cases/helper"
require 'ipaddr'

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter
      class QuotingTest < ActiveRecord::TestCase
        def setup
          @conn = ActiveRecord::Base.connection
        end

        def test_type_cast_true
          assert_equal 't', @conn.type_cast(true)
        end

        def test_type_cast_false
          assert_equal 'f', @conn.type_cast(false)
        end

        def test_quote_float_nan
          nan = 0.0/0
          assert_equal "'NaN'", @conn.quote(nan)
        end

        def test_quote_float_infinity
          infinity = 1.0/0
          assert_equal "'Infinity'", @conn.quote(infinity)
        end

        def test_quote_time_usec
          assert_equal "'1970-01-01 00:00:00.000000'", @conn.quote(Time.at(0))
          assert_equal "'1970-01-01 00:00:00.000000'", @conn.quote(Time.at(0).to_datetime)
        end

        def test_quote_range
          range = "1,2]'; SELECT * FROM users; --".."a"
          c = PostgreSQLColumn.new(nil, nil, OID::Range.new(Type::Integer.new, :int8range))
          assert_equal "'[1,0]'", @conn.quote(range, c)
        end

        def test_quote_bit_string
          c = PostgreSQLColumn.new(nil, 1, OID::Bit.new)
          assert_equal nil, @conn.quote("'); SELECT * FROM users; /*\n01\n*/--", c)
        end
      end
    end
  end
end
