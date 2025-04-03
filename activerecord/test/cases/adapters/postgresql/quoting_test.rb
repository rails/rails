# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter
      class QuotingTest < ActiveRecord::PostgreSQLTestCase
        def setup
          @conn = ActiveRecord::Base.lease_connection
          @raise_int_wider_than_64bit = ActiveRecord.raise_int_wider_than_64bit
        end

        def test_type_cast_true
          assert_equal true, @conn.type_cast(true)
        end

        def test_type_cast_false
          assert_equal false, @conn.type_cast(false)
        end

        def test_quote_float_nan
          nan = 0.0 / 0
          assert_equal "'NaN'", @conn.quote(nan)
        end

        def test_quote_float_infinity
          infinity = 1.0 / 0
          assert_equal "'Infinity'", @conn.quote(infinity)
        end

        def test_quote_integer
          assert_equal "42", @conn.quote(42)
        end

        def test_quote_big_decimal
          assert_equal "4.2", @conn.quote(BigDecimal("4.2"))
        end

        def test_quote_rational
          assert_equal "3/4", @conn.quote(Rational(3, 4))
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

        def test_quote_table_name_with_spaces
          value = "user posts"
          assert_equal "\"user posts\"", @conn.quote_table_name(value)
        end

        def test_quote_string
          assert_equal "''", @conn.quote_string("'")
        end

        def test_quote_column_name
          [@conn, @conn.class].each do |adapter|
            assert_equal '"foo"', adapter.quote_column_name("foo")
            assert_equal '"hel""lo"', adapter.quote_column_name(%{hel"lo})
          end
        end

        def test_quote_table_name
          [@conn, @conn.class].each do |adapter|
            assert_equal '"foo"', adapter.quote_table_name("foo")
            assert_equal '"foo"."bar"', adapter.quote_table_name("foo.bar")
            assert_equal '"hel""lo.wol\\d"', adapter.quote_column_name('hel"lo.wol\\d')
          end
        end

        def test_raise_when_int_is_wider_than_64bit
          value = 9223372036854775807 + 1
          assert_raise ActiveRecord::ConnectionAdapters::PostgreSQL::Quoting::IntegerOutOf64BitRange do
            @conn.quote(value)
          end

          value = -9223372036854775808 - 1
          assert_raise ActiveRecord::ConnectionAdapters::PostgreSQL::Quoting::IntegerOutOf64BitRange do
            @conn.quote(value)
          end
        end

        def test_do_not_raise_when_int_is_not_wider_than_64bit
          value = 9223372036854775807
          assert_equal "9223372036854775807", @conn.quote(value)

          value = -9223372036854775808
          assert_equal "-9223372036854775808", @conn.quote(value)
        end

        def test_do_not_raise_when_raise_int_wider_than_64bit_is_false
          ActiveRecord.raise_int_wider_than_64bit = false
          value = 9223372036854775807 + 1
          assert_equal "9223372036854775808", @conn.quote(value)
          ActiveRecord.raise_int_wider_than_64bit = @raise_int_wider_than_64bit
        end
      end
    end
  end
end
