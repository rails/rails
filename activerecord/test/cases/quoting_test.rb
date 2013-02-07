require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class QuotingTest < ActiveRecord::TestCase
      class FakeColumn < ActiveRecord::ConnectionAdapters::Column
        attr_accessor :type

        def initialize type
          @type = type
        end
      end

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
        assert_equal "foo", @quoter.quote_column_name('foo')
      end

      def test_quote_table_name
        assert_equal "foo", @quoter.quote_table_name('foo')
      end

      def test_quote_table_name_calls_quote_column_name
        @quoter.extend(Module.new {
          def quote_column_name(string)
            'lol'
          end
        })
        assert_equal 'lol', @quoter.quote_table_name('foo')
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

      def test_quoted_time_utc
        before = ActiveRecord::Base.default_timezone
        ActiveRecord::Base.default_timezone = :utc
        t = Time.now
        assert_equal t.getutc.to_s(:db), @quoter.quoted_date(t)
      ensure
        ActiveRecord::Base.default_timezone = before
      end

      def test_quoted_time_local
        before = ActiveRecord::Base.default_timezone
        ActiveRecord::Base.default_timezone = :local
        t = Time.now
        assert_equal t.getlocal.to_s(:db), @quoter.quoted_date(t)
      ensure
        ActiveRecord::Base.default_timezone = before
      end

      def test_quoted_time_crazy
        before = ActiveRecord::Base.default_timezone
        ActiveRecord::Base.default_timezone = :asdfasdf
        t = Time.now
        assert_equal t.getlocal.to_s(:db), @quoter.quoted_date(t)
      ensure
        ActiveRecord::Base.default_timezone = before
      end

      def test_quoted_datetime_utc
        before = ActiveRecord::Base.default_timezone
        ActiveRecord::Base.default_timezone = :utc
        t = DateTime.now
        assert_equal t.getutc.to_s(:db), @quoter.quoted_date(t)
      ensure
        ActiveRecord::Base.default_timezone = before
      end

      ###
      # DateTime doesn't define getlocal, so make sure it does nothing
      def test_quoted_datetime_local
        before = ActiveRecord::Base.default_timezone
        ActiveRecord::Base.default_timezone = :local
        t = DateTime.now
        assert_equal t.to_s(:db), @quoter.quoted_date(t)
      ensure
        ActiveRecord::Base.default_timezone = before
      end

      def test_quote_with_quoted_id
        assert_equal 1, @quoter.quote(Struct.new(:quoted_id).new(1), nil)
        assert_equal 1, @quoter.quote(Struct.new(:quoted_id).new(1), 'foo')
      end

      def test_quote_nil
        assert_equal 'NULL', @quoter.quote(nil, nil)
        assert_equal 'NULL', @quoter.quote(nil, 'foo')
      end

      def test_quote_true
        assert_equal @quoter.quoted_true, @quoter.quote(true, nil)
        assert_equal '1', @quoter.quote(true, Struct.new(:type).new(:integer))
      end

      def test_quote_false
        assert_equal @quoter.quoted_false, @quoter.quote(false, nil)
        assert_equal '0', @quoter.quote(false, Struct.new(:type).new(:integer))
      end

      def test_quote_float
        float = 1.2
        assert_equal float.to_s, @quoter.quote(float, nil)
        assert_equal float.to_s, @quoter.quote(float, FakeColumn.new(:float))
      end

      def test_quote_fixnum
        fixnum = 1
        assert_equal fixnum.to_s, @quoter.quote(fixnum, nil)
        assert_equal fixnum.to_s, @quoter.quote(fixnum, FakeColumn.new(:integer))
      end

      def test_quote_bignum
        bignum = 1 << 100
        assert_equal bignum.to_s, @quoter.quote(bignum, nil)
        assert_equal bignum.to_s, @quoter.quote(bignum, FakeColumn.new(:integer))
      end

      def test_quote_bigdecimal
        bigdec = BigDecimal.new((1 << 100).to_s)
        assert_equal bigdec.to_s('F'), @quoter.quote(bigdec, nil)
        assert_equal bigdec.to_s('F'), @quoter.quote(bigdec, FakeColumn.new(:decimal))
      end

      def test_dates_and_times
        @quoter.extend(Module.new { def quoted_date(value) 'lol' end })
        assert_equal "'lol'", @quoter.quote(Date.today, nil)
        assert_equal "'lol'", @quoter.quote(Date.today, FakeColumn.new(:date))
        assert_equal "'lol'", @quoter.quote(Time.now, nil)
        assert_equal "'lol'", @quoter.quote(Time.now, FakeColumn.new(:time))
        assert_equal "'lol'", @quoter.quote(DateTime.now, nil)
        assert_equal "'lol'", @quoter.quote(DateTime.now, FakeColumn.new(:datetime))
      end

      def test_crazy_object
        crazy = Class.new.new
        expected = "'#{YAML.dump(crazy)}'"
        assert_equal expected, @quoter.quote(crazy, nil)
        assert_equal expected, @quoter.quote(crazy, Object.new)
      end

      def test_crazy_object_calls_quote_string
        crazy = Class.new { def initialize; @lol = 'lo\l' end }.new
        assert_match "lo\\\\l", @quoter.quote(crazy, nil)
        assert_match "lo\\\\l", @quoter.quote(crazy, Object.new)
      end

      def test_quote_string_no_column
        assert_equal "'lo\\\\l'", @quoter.quote('lo\l', nil)
      end

      def test_quote_as_mb_chars_no_column
        string = ActiveSupport::Multibyte::Chars.new('lo\l')
        assert_equal "'lo\\\\l'", @quoter.quote(string, nil)
      end

      def test_quote_string_int_column
        assert_equal "1", @quoter.quote('1', FakeColumn.new(:integer))
        assert_equal "1", @quoter.quote('1.2', FakeColumn.new(:integer))
      end

      def test_quote_string_float_column
        assert_equal "1.0", @quoter.quote('1', FakeColumn.new(:float))
        assert_equal "1.2", @quoter.quote('1.2', FakeColumn.new(:float))
      end

      def test_quote_as_mb_chars_binary_column
        string = ActiveSupport::Multibyte::Chars.new('lo\l')
        assert_equal "'lo\\\\l'", @quoter.quote(string, FakeColumn.new(:binary))
      end

      def test_quote_binary_without_string_to_binary
        assert_equal "'lo\\\\l'", @quoter.quote('lo\l', FakeColumn.new(:binary))
      end

      def test_quote_binary_with_string_to_binary
        col = Class.new(FakeColumn) {
          def string_to_binary(value)
            'foo'
          end
        }.new(:binary)
        assert_equal "'foo'", @quoter.quote('lo\l', col)
      end

      def test_quote_as_mb_chars_binary_column_with_string_to_binary
        col = Class.new(FakeColumn) {
          def string_to_binary(value)
            'foo'
          end
        }.new(:binary)
        string = ActiveSupport::Multibyte::Chars.new('lo\l')
        assert_equal "'foo'", @quoter.quote(string, col)
      end

      def test_string_with_crazy_column
        assert_equal "'lo\\\\l'", @quoter.quote('lo\l', FakeColumn.new(:foo))
      end

      def test_quote_duration
        assert_equal "1800", @quoter.quote(30.minutes)
      end

      def test_quote_duration_int_column
        assert_equal "7200", @quoter.quote(2.hours, FakeColumn.new(:integer))
      end
    end
  end
end
