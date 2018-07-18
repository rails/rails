require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class QuotingTest < ActiveRecord::TestCase
      def setup
        @quoter = Class.new { include Quoting }.new
      end

      def test_quoted_true
        assert_equal "'t'", @quoter.quoted_true
      end

      def test_quoted_false
        assert_equal "'f'", @quoter.quoted_false
      end

      def test_quote_column_name
        assert_equal "foo", @quoter.quote_column_name("foo")
      end

      def test_quote_table_name
        assert_equal "foo", @quoter.quote_table_name("foo")
      end

      def test_quote_table_name_calls_quote_column_name
        @quoter.extend(Module.new {
          def quote_column_name(string)
            "lol"
          end
        })
        assert_equal "lol", @quoter.quote_table_name("foo")
      end

      def test_quote_string
        assert_equal "''", @quoter.quote_string("'")
        assert_equal "\\\\", @quoter.quote_string("\\")
        assert_equal "hi''i", @quoter.quote_string("hi'i")
        assert_equal "hi\\\\i", @quoter.quote_string("hi\\i")
      end

      def test_quoted_date
        t = Date.today
        assert_equal t.to_s(:db), @quoter.quoted_date(t)
      end

      def test_quoted_timestamp_utc
        with_timezone_config default: :utc do
          t = Time.now.change(usec: 0)
          assert_equal t.getutc.to_s(:db), @quoter.quoted_date(t)
        end
      end

      def test_quoted_timestamp_local
        with_timezone_config default: :local do
          t = Time.now.change(usec: 0)
          assert_equal t.getlocal.to_s(:db), @quoter.quoted_date(t)
        end
      end

      def test_quoted_timestamp_crazy
        with_timezone_config default: :asdfasdf do
          t = Time.now.change(usec: 0)
          assert_equal t.getlocal.to_s(:db), @quoter.quoted_date(t)
        end
      end

      def test_quoted_time_utc
        with_timezone_config default: :utc do
          t = Time.now.change(usec: 0)

          expected = t.change(year: 2000, month: 1, day: 1)
          expected = expected.getutc.to_s(:db).slice(11..-1)

          assert_equal expected, @quoter.quoted_time(t)
        end
      end

      def test_quoted_time_local
        with_timezone_config default: :local do
          t = Time.now.change(usec: 0)

          expected = t.change(year: 2000, month: 1, day: 1)
          expected = expected.getlocal.to_s(:db).sub("2000-01-01 ", "")

          assert_equal expected, @quoter.quoted_time(t)
        end
      end

      def test_quoted_time_dst_utc
        with_timezone_config default: :utc do
          t = Time.new(2000, 7, 1, 0, 0, 0, "+04:30")

          expected = t.change(year: 2000, month: 1, day: 1)
          expected = expected.getutc.to_s(:db).slice(11..-1)

          assert_equal expected, @quoter.quoted_time(t)
        end
      end

      def test_quoted_time_dst_local
        with_timezone_config default: :local do
          t = Time.new(2000, 7, 1, 0, 0, 0, "+04:30")

          expected = t.change(year: 2000, month: 1, day: 1)
          expected = expected.getlocal.to_s(:db).slice(11..-1)

          assert_equal expected, @quoter.quoted_time(t)
        end
      end

      def test_quoted_time_crazy
        with_timezone_config default: :asdfasdf do
          t = Time.now.change(usec: 0)

          expected = t.change(year: 2000, month: 1, day: 1)
          expected = expected.getlocal.to_s(:db).sub("2000-01-01 ", "")

          assert_equal expected, @quoter.quoted_time(t)
        end
      end

      def test_quoted_datetime_utc
        with_timezone_config default: :utc do
          t = Time.now.change(usec: 0).to_datetime
          assert_equal t.getutc.to_s(:db), @quoter.quoted_date(t)
        end
      end

      ###
      # DateTime doesn't define getlocal, so make sure it does nothing
      def test_quoted_datetime_local
        with_timezone_config default: :local do
          t = Time.now.change(usec: 0).to_datetime
          assert_equal t.to_s(:db), @quoter.quoted_date(t)
        end
      end

      class QuotedOne
        def quoted_id
          1
        end
      end
      class SubQuotedOne < QuotedOne
      end
      def test_quote_with_quoted_id
        assert_deprecated(/defined on \S+::QuotedOne at .*quoting_test\.rb:[0-9]/) do
          assert_equal 1, @quoter.quote(QuotedOne.new)
        end

        assert_deprecated(/defined on \S+::SubQuotedOne\(\S+::QuotedOne\) at .*quoting_test\.rb:[0-9]/) do
          assert_equal 1, @quoter.quote(SubQuotedOne.new)
        end
      end

      def test_quote_nil
        assert_equal "NULL", @quoter.quote(nil)
      end

      def test_quote_true
        assert_equal @quoter.quoted_true, @quoter.quote(true)
      end

      def test_quote_false
        assert_equal @quoter.quoted_false, @quoter.quote(false)
      end

      def test_quote_float
        float = 1.2
        assert_equal float.to_s, @quoter.quote(float)
      end

      def test_quote_integer
        integer = 1
        assert_equal integer.to_s, @quoter.quote(integer)
      end

      def test_quote_bignum
        bignum = 1 << 100
        assert_equal bignum.to_s, @quoter.quote(bignum)
      end

      def test_quote_bigdecimal
        bigdec = BigDecimal((1 << 100).to_s)
        assert_equal bigdec.to_s("F"), @quoter.quote(bigdec)
      end

      def test_dates_and_times
        @quoter.extend(Module.new { def quoted_date(value) "lol" end })
        assert_equal "'lol'", @quoter.quote(Date.today)
        assert_equal "'lol'", @quoter.quote(Time.now)
        assert_equal "'lol'", @quoter.quote(DateTime.now)
      end

      def test_quoting_classes
        assert_equal "'Object'", @quoter.quote(Object)
      end

      def test_crazy_object
        crazy = Object.new
        e = assert_raises(TypeError) do
          @quoter.quote(crazy)
        end
        assert_equal "can't quote Object", e.message
      end

      def test_quote_string_no_column
        assert_equal "'lo\\\\l'", @quoter.quote('lo\l')
      end

      def test_quote_as_mb_chars_no_column
        string = ActiveSupport::Multibyte::Chars.new('lo\l')
        assert_equal "'lo\\\\l'", @quoter.quote(string)
      end

      def test_quote_duration
        assert_equal "1800", @quoter.quote(30.minutes)
      end
    end

    class TypeCastingTest < ActiveRecord::TestCase
      def setup
        @conn = ActiveRecord::Base.connection
      end

      def test_type_cast_symbol
        assert_equal "foo", @conn.type_cast(:foo)
      end

      def test_type_cast_date
        date = Date.today
        expected = @conn.quoted_date(date)
        assert_equal expected, @conn.type_cast(date)
      end

      def test_type_cast_time
        time = Time.now
        expected = @conn.quoted_date(time)
        assert_equal expected, @conn.type_cast(time)
      end

      def test_type_cast_numeric
        assert_equal 10, @conn.type_cast(10)
        assert_equal 2.2, @conn.type_cast(2.2)
      end

      def test_type_cast_nil
        assert_nil @conn.type_cast(nil)
      end

      def test_type_cast_unknown_should_raise_error
        obj = Class.new.new
        assert_raise(TypeError) { @conn.type_cast(obj) }
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
        assert_equal 10, @conn.type_cast(quoted_id_obj)

        quoted_id_obj = Class.new {
          def quoted_id
            "'zomg'"
          end
        }.new
        assert_raise(TypeError) { @conn.type_cast(quoted_id_obj) }
      end
    end

    class QuoteBooleanTest < ActiveRecord::TestCase
      def setup
        @connection = ActiveRecord::Base.connection
      end

      def test_quote_returns_frozen_string
        assert_predicate @connection.quote(true), :frozen?
        assert_predicate @connection.quote(false), :frozen?
      end

      def test_type_cast_returns_frozen_value
        assert_predicate @connection.type_cast(true), :frozen?
        assert_predicate @connection.type_cast(false), :frozen?
      end
    end

    if subsecond_precision_supported?
      class QuoteARBaseTest < ActiveRecord::TestCase
        class DatetimePrimaryKey < ActiveRecord::Base
        end

        def setup
          @time = ::Time.utc(2017, 2, 14, 12, 34, 56, 789999)
          @connection = ActiveRecord::Base.connection
          @connection.create_table :datetime_primary_keys, id: :datetime, precision: 3, force: true
        end

        def teardown
          @connection.drop_table :datetime_primary_keys, if_exists: true
        end

        def test_quote_ar_object
          value = DatetimePrimaryKey.new(id: @time)
          assert_equal "'2017-02-14 12:34:56.789000'",  @connection.quote(value)
        end

        def test_type_cast_ar_object
          value = DatetimePrimaryKey.new(id: @time)
          assert_equal "2017-02-14 12:34:56.789000",  @connection.type_cast(value)
        end
      end
    end
  end
end
