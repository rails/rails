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

      def test_quote_string
        assert_equal "''", @quoter.quote_string("'")
        assert_equal "\\\\", @quoter.quote_string("\\")
        assert_equal "hi''i", @quoter.quote_string("hi'i")
        assert_equal "hi\\\\i", @quoter.quote_string("hi\\i")
      end
    end
  end
end
