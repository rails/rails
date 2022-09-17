# frozen_string_literal: true

require "cases/helper"
require "models/post"

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter
      class BindParameterTest < ActiveRecord::PostgreSQLTestCase
        fixtures :posts

        def test_where_with_string_for_string_column_using_bind_parameters
          count = Post.where("title = ?", "Welcome to the weblog").count
          assert_equal 1, count
        end

        def test_where_with_integer_for_string_column_using_bind_parameters
          assert_raises ActiveRecord::StatementInvalid do
            Post.where("title = ?", 0).count
          end
        end

        def test_where_with_float_for_string_column_using_bind_parameters
          assert_raises ActiveRecord::StatementInvalid do
            Post.where("title = ?", 0.0).count
          end
        end

        def test_where_with_boolean_for_string_column_using_bind_parameters
          assert_raises ActiveRecord::StatementInvalid do
            Post.where("title = ?", false).count
          end
        end

        def test_where_with_decimal_for_string_column_using_bind_parameters
          assert_raises ActiveRecord::StatementInvalid do
            Post.where("title = ?", BigDecimal(0)).count
          end
        end

        def test_where_with_rational_for_string_column_using_bind_parameters
          assert_raises ActiveRecord::StatementInvalid do
            Post.where("title = ?", Rational(0)).count
          end
        end

        def test_where_with_duration_for_string_column_using_bind_parameters
          assert_raises ActiveRecord::StatementInvalid do
            assert_deprecated { Post.where("title = ?", 0.seconds).count }
          end
        end
      end
    end
  end
end
