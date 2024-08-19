# frozen_string_literal: true

require "cases/helper"
require "models/post"

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter
      class BindParameterTest < ActiveRecord::PostgreSQLTestCase
        fixtures :posts

        def test_where_with_string_for_string_column_using_bind_parameters
          assert_quoted_as "'Welcome to the weblog'", "Welcome to the weblog", match: 1
        end

        def test_where_with_integer_for_string_column_using_bind_parameters
          assert_quoted_as "0", 0
        end

        def test_where_with_float_for_string_column_using_bind_parameters
          assert_quoted_as "0.0", 0.0
        end

        def test_where_with_boolean_for_string_column_using_bind_parameters
          assert_quoted_as "FALSE", false
        end

        def test_where_with_decimal_for_string_column_using_bind_parameters
          assert_quoted_as "0.0", BigDecimal(0)
        end

        def test_where_with_rational_for_string_column_using_bind_parameters
          assert_quoted_as "0/1", Rational(0)
        end

        def test_where_with_nil_for_string_column_using_bind_parameters
          post = Post.create!
          relation = Post.where("LOWER(title) IS ?", nil)
          assert_equal post, relation.first

          expected_sql = %{SELECT "posts".* FROM "posts" WHERE (LOWER(title) IS NULL)}
          assert_equal(expected_sql, relation.to_sql)
        end

        private
          def assert_quoted_as(expected, value, match: 0)
            relation = Post.where("title = ?", value)
            assert_equal(
              %{SELECT "posts".* FROM "posts" WHERE (title = #{expected})},
              relation.to_sql,
            )
            if match == 0
              assert_empty relation.to_a
            else
              assert_equal match, relation.count
            end
          end
      end
    end
  end
end
