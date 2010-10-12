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
        assert_equal float.to_s, @quoter.quote(float, Object.new)
      end

      def test_quote_fixnum
        fixnum = 1
        assert_equal fixnum.to_s, @quoter.quote(fixnum, nil)
        assert_equal fixnum.to_s, @quoter.quote(fixnum, Object.new)
      end

      def test_quote_bignum
        bignum = 1 << 100
        assert_equal bignum.to_s, @quoter.quote(bignum, nil)
        assert_equal bignum.to_s, @quoter.quote(bignum, Object.new)
      end
    end
  end
end
