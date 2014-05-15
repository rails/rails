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
          c = PostgreSQLColumn.new(nil, 1, OID::Boolean.new, 'boolean')
          assert_equal 't', @conn.type_cast(true, nil)
          assert_equal 't', @conn.type_cast(true, c)
        end

        def test_type_cast_false
          c = PostgreSQLColumn.new(nil, 1, OID::Boolean.new, 'boolean')
          assert_equal 'f', @conn.type_cast(false, nil)
          assert_equal 'f', @conn.type_cast(false, c)
        end

        def test_type_cast_cidr
          ip = IPAddr.new('255.0.0.0/8')
          c = PostgreSQLColumn.new(nil, ip, OID::Cidr.new, 'cidr')
          assert_equal ip, @conn.type_cast(ip, c)
        end

        def test_type_cast_inet
          ip = IPAddr.new('255.1.0.0/8')
          c = PostgreSQLColumn.new(nil, ip, OID::Cidr.new, 'inet')
          assert_equal ip, @conn.type_cast(ip, c)
        end

        def test_quote_float_nan
          nan = 0.0/0
          c = PostgreSQLColumn.new(nil, 1, OID::Float.new, 'float')
          assert_equal "'NaN'", @conn.quote(nan, c)
        end

        def test_quote_float_infinity
          infinity = 1.0/0
          c = PostgreSQLColumn.new(nil, 1, OID::Float.new, 'float')
          assert_equal "'Infinity'", @conn.quote(infinity, c)
        end

        def test_quote_cast_numeric
          fixnum = 666
          c = PostgreSQLColumn.new(nil, nil, OID::String.new, 'varchar')
          assert_equal "'666'", @conn.quote(fixnum, c)
          c = PostgreSQLColumn.new(nil, nil, OID::Text.new, 'text')
          assert_equal "'666'", @conn.quote(fixnum, c)
        end

        def test_quote_time_usec
          assert_equal "'1970-01-01 00:00:00.000000'", @conn.quote(Time.at(0))
          assert_equal "'1970-01-01 00:00:00.000000'", @conn.quote(Time.at(0).to_datetime)
        end
      end
    end
  end
end
