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
          c = Column.new(nil, 1, 'boolean')
          assert_equal 't', @conn.type_cast(true, nil)
          assert_equal 't', @conn.type_cast(true, c)
        end

        def test_type_cast_false
          c = Column.new(nil, 1, 'boolean')
          assert_equal 'f', @conn.type_cast(false, nil)
          assert_equal 'f', @conn.type_cast(false, c)
        end

        def test_type_cast_cidr
          ip = IPAddr.new('255.0.0.0/8')
          c = Column.new(nil, ip, 'cidr')
          assert_equal ip, @conn.type_cast(ip, c)
        end

        def test_type_cast_inet
          ip = IPAddr.new('255.1.0.0/8')
          c = Column.new(nil, ip, 'inet')
          assert_equal ip, @conn.type_cast(ip, c)
        end

        def test_quote_float_nan
          nan = 0.0/0
          c = Column.new(nil, 1, 'float')
          assert_equal "'NaN'", @conn.quote(nan, c)
        end

        def test_quote_float_infinity
          infinity = 1.0/0
          c = Column.new(nil, 1, 'float')
          assert_equal "'Infinity'", @conn.quote(infinity, c)
        end

        def test_quote_cast_numeric
          fixnum = 666
          c = Column.new(nil, nil, 'string')
          assert_equal "'666'", @conn.quote(fixnum, c)
          c = Column.new(nil, nil, 'text')
          assert_equal "'666'", @conn.quote(fixnum, c)
        end

        def test_quote_range
          range = "1,2]'; SELECT * FROM users; --".."a"
          c = PostgreSQLColumn.new(nil, nil, OID::Range.new(:integer), 'int8range')
          assert_equal "'[1,2]''; SELECT * FROM users; --,a]'::int8range", @conn.quote(range, c)
        end
      end
    end
  end
end
