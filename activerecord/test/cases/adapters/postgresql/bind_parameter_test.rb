# frozen_string_literal: true

require "cases/helper"
require "models/post"

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter
      class BindParameterTest < ActiveRecord::PostgreSQLTestCase
        fixtures :posts

        def test_where_with_string_for_string_column_using_bind_parameters
          assert_quoted_as "'Welcome to the weblog'", "Welcome to the weblog"
        end

        def test_where_with_integer_for_string_column_using_bind_parameters
          assert_quoted_as "0", 0, valid: false
        end

        def test_where_with_float_for_string_column_using_bind_parameters
          assert_quoted_as "0.0", 0.0, valid: false
        end

        def test_where_with_boolean_for_string_column_using_bind_parameters
          assert_quoted_as "FALSE", false, valid: false
        end

        def test_where_with_decimal_for_string_column_using_bind_parameters
          assert_quoted_as "0.0", BigDecimal(0), valid: false
        end

        def test_where_with_rational_for_string_column_using_bind_parameters
          assert_quoted_as "0/1", Rational(0), valid: false
        end

        private
          def assert_quoted_as(expected, value, valid: true)
            relation = Post.where("title = ?", value)
            assert_equal(
              %{SELECT "posts".* FROM "posts" WHERE (title = #{expected})},
              relation.to_sql,
            )
            if valid
              assert_nothing_raised do # Make sure SQL is valid
                relation.to_a
              end
            else
              assert_raises ActiveRecord::StatementInvalid do
                relation.to_a
              end
            end
          end
      end
    end
  end
end
