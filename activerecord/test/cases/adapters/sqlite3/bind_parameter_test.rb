# frozen_string_literal: true

require "cases/helper"
require "models/post"

module ActiveRecord
  module ConnectionAdapters
    class SQLite3Adapter
      class BindParameterTest < ActiveRecord::SQLite3TestCase
        fixtures :posts

        def test_where_with_string_for_string_column_using_bind_parameters
          count = Post.where("title = ?", "Welcome to the weblog").count
          assert_equal 1, count
        end

        def test_where_with_integer_for_string_column_using_bind_parameters
          count = Post.where("title = ?", 0).count
          assert_equal 0, count
        end

        def test_where_with_float_for_string_column_using_bind_parameters
          count = Post.where("title = ?", 0.0).count
          assert_equal 0, count
        end

        def test_where_with_boolean_for_string_column_using_bind_parameters
          count = Post.where("title = ?", false).count
          assert_equal 0, count
        end

        def test_where_with_decimal_for_string_column_using_bind_parameters
          count = Post.where("title = ?", BigDecimal(0)).count
          assert_equal 0, count
        end

        def test_where_with_rational_for_string_column_using_bind_parameters
          count = Post.where("title = ?", Rational(0)).count
          assert_equal 0, count
        end

        def test_where_with_duration_for_string_column_using_bind_parameters
          count = assert_deprecated { Post.where("title = ?", 0.seconds).count }
          assert_equal 0, count
        end
      end
    end
  end
end
