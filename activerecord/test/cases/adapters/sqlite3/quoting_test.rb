require "cases/helper"
require 'bigdecimal'
require 'yaml'
require 'securerandom'

module ActiveRecord
  module ConnectionAdapters
    class SQLite3Adapter
      class QuotingTest < ActiveRecord::TestCase
        def setup
          @conn = Base.sqlite3_connection :database => ':memory:',
            :adapter => 'sqlite3',
            :timeout => 100
        end

        def test_type_cast_binary_encoding_without_logger
          @conn.extend(Module.new { def logger; end })
          column = Column.new(nil, nil, Type::String.new)
          binary = SecureRandom.hex
          expected = binary.dup.encode!(Encoding::UTF_8)
          assert_equal expected, @conn.type_cast(binary, column)
        end

        def test_type_cast_symbol
          assert_equal 'foo', @conn.type_cast(:foo, nil)
        end

        def test_type_cast_date
          date = Date.today
          expected = @conn.quoted_date(date)
          assert_equal expected, @conn.type_cast(date, nil)
        end

        def test_type_cast_time
          time = Time.now
          expected = @conn.quoted_date(time)
          assert_equal expected, @conn.type_cast(time, nil)
        end

        def test_type_cast_numeric
          assert_equal 10, @conn.type_cast(10, nil)
          assert_equal 2.2, @conn.type_cast(2.2, nil)
        end

        def test_type_cast_nil
          assert_equal nil, @conn.type_cast(nil, nil)
        end

        def test_type_cast_true
          c = Column.new(nil, 1, Type::Integer.new)
          assert_equal 't', @conn.type_cast(true, nil)
          assert_equal 1, @conn.type_cast(true, c)
        end

        def test_type_cast_false
          c = Column.new(nil, 1, Type::Integer.new)
          assert_equal 'f', @conn.type_cast(false, nil)
          assert_equal 0, @conn.type_cast(false, c)
        end

        def test_type_cast_string
          assert_equal '10', @conn.type_cast('10', nil)

          c = Column.new(nil, 1, Type::Integer.new)
          assert_equal 10, @conn.type_cast('10', c)

          c = Column.new(nil, 1, Type::Float.new)
          assert_equal 10.1, @conn.type_cast('10.1', c)

          c = Column.new(nil, 1, Type::Binary.new)
          assert_equal '10.1', @conn.type_cast('10.1', c)

          c = Column.new(nil, 1, Type::Date.new)
          assert_equal '2016-05-11', @conn.type_cast('2016-05-11 19:00:00', c)
        end

        def test_type_cast_bigdecimal
          bd = BigDecimal.new '10.0'
          assert_equal bd.to_f, @conn.type_cast(bd, nil)
        end

        def test_type_cast_unknown_should_raise_error
          obj = Class.new.new
          assert_raise(TypeError) { @conn.type_cast(obj, nil) }
        end

        def test_type_cast_object_which_responds_to_quoted_id
          quoted_id_obj = Class.new {
            def quoted_id
              "'zomg'"
            end

            def id
              10
            end
          }.new
          assert_equal 10, @conn.type_cast(quoted_id_obj, nil)

          quoted_id_obj = Class.new {
            def quoted_id
              "'zomg'"
            end
          }.new
          assert_raise(TypeError) { @conn.type_cast(quoted_id_obj, nil) }
        end

        def test_quoting_binary_strings
          value = "hello".encode('ascii-8bit')
          column = Column.new(nil, 1, Type::String.new)

          assert_equal "'hello'", @conn.quote(value, column)
        end
      end
    end
  end
end
