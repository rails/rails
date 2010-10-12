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
    end
  end
end
