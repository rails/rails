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
        with_timezone_config default: :utc do
          t = Time.now
          assert_equal t.getutc.to_s(:db), @quoter.quoted_date(t)
        end
      end

      def test_quoted_time_local
        with_timezone_config default: :local do
          t = Time.now
          assert_equal t.getlocal.to_s(:db), @quoter.quoted_date(t)
        end
      end

      def test_quoted_time_crazy
        with_timezone_config default: :asdfasdf do
          t = Time.now
          assert_equal t.getlocal.to_s(:db), @quoter.quoted_date(t)
        end
      end

      def test_quoted_datetime_utc
        with_timezone_config default: :utc do
          t = DateTime.now
          assert_equal t.getutc.to_s(:db), @quoter.quoted_date(t)
        end
      end

      ###
      # DateTime doesn't define getlocal, so make sure it does nothing
      def test_quoted_datetime_local
        with_timezone_config default: :local do
          t = DateTime.now
          assert_equal t.to_s(:db), @quoter.quoted_date(t)
        end
      end

      def test_quote_with_quoted_id
        assert_equal 1, @quoter.quote(Struct.new(:quoted_id).new(1), nil)
      end

      def test_quote_nil
        assert_equal 'NULL', @quoter.quote(nil, nil)
      end

      def test_quote_true
        assert_equal @quoter.quoted_true, @quoter.quote(true, nil)
      end

      def test_quote_false
        assert_equal @quoter.quoted_false, @quoter.quote(false, nil)
      end

      def test_quote_float
        float = 1.2
        assert_equal float.to_s, @quoter.quote(float, nil)
      end

      def test_quote_fixnum
        fixnum = 1
        assert_equal fixnum.to_s, @quoter.quote(fixnum, nil)
      end

      def test_quote_bignum
        bignum = 1 << 100
        assert_equal bignum.to_s, @quoter.quote(bignum, nil)
      end

      def test_quote_bigdecimal
        bigdec = BigDecimal.new((1 << 100).to_s)
        assert_equal bigdec.to_s('F'), @quoter.quote(bigdec, nil)
      end

      def test_dates_and_times
        @quoter.extend(Module.new { def quoted_date(value) 'lol' end })
        assert_equal "'lol'", @quoter.quote(Date.today, nil)
        assert_equal "'lol'", @quoter.quote(Time.now, nil)
        assert_equal "'lol'", @quoter.quote(DateTime.now, nil)
      end

      def test_crazy_object
        crazy = Class.new.new
        expected = "'#{YAML.dump(crazy)}'"
        assert_equal expected, @quoter.quote(crazy, nil)
      end

      def test_crazy_object_calls_quote_string
        crazy = Class.new { def initialize; @lol = 'lo\l' end }.new
        assert_match "lo\\\\l", @quoter.quote(crazy, nil)
      end

      def test_quote_string_no_column
        assert_equal "'lo\\\\l'", @quoter.quote('lo\l', nil)
      end

      def test_quote_as_mb_chars_no_column
        string = ActiveSupport::Multibyte::Chars.new('lo\l')
        assert_equal "'lo\\\\l'", @quoter.quote(string, nil)
      end

      def test_string_with_crazy_column
        assert_equal "'lo\\\\l'", @quoter.quote('lo\l')
      end

      def test_quote_duration
        assert_equal "1800", @quoter.quote(30.minutes)
      end
    end
  end
end
