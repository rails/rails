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

        def test_find_by_sql_with_bind_parameter_as_typed_literal_hints_a_cast
          error = assert_bind_parameter_hint { Post.find_by_sql(["SELECT DATE :day AS day", { day: "2026-01-02" }]) }
          assert_includes error.message, "CAST($1 AS date) or $1::date"
        end

        def test_where_with_bind_parameter_after_is_hints_the_literal
          error = assert_bind_parameter_hint { Post.where("title IS ?", nil).to_a }
          assert_includes error.message, "Hint: IS takes only NULL, TRUE, FALSE or UNKNOWN, not $1."
        end

        def test_count_by_sql_with_bind_parameter_as_typed_literal_hints_a_cast
          error = assert_bind_parameter_hint do
            Post.count_by_sql(["SELECT COUNT(*) FROM posts WHERE id > ? AND NOW() > TIMESTAMP WITH TIME ZONE ?", 0, "2026-01-02"])
          end
          assert_includes error.message, "Hint: $2 cannot follow timestamp with time zone as a typed literal."
        end

        def test_where_with_bind_parameter_after_is_not_hints_the_literal
          error = assert_bind_parameter_hint { Post.where("title IS NOT ?", nil).to_a }
          assert_includes error.message, "Hint: IS NOT takes only NULL, TRUE, FALSE or UNKNOWN, not $1."
          assert_includes error.message, "IS DISTINCT FROM $1"
        end

        def test_other_syntax_errors_at_a_bind_parameter_get_no_hint
          skip unless Post.lease_connection.prepared_statements

          error = assert_raises(ActiveRecord::StatementInvalid) { Post.find_by_sql(["SELECT dates ?", "2026-01-02"]) }
          assert_includes error.message, 'syntax error at or near "$1"'
          assert_not_includes error.message, "Hint:"
        end

        def test_keyword_in_a_string_literal_gets_no_hint
          assert_no_bind_parameter_hint "SELECT 'DATE $1', 1 + $1 $1"
        end

        def test_keyword_in_a_block_comment_gets_no_hint
          assert_no_bind_parameter_hint "SELECT 1 + $1 $1 /* DATE $1 */"
        end

        def test_keyword_in_a_line_comment_gets_no_hint
          assert_no_bind_parameter_hint "SELECT 1 $1 -- IS $1"
          assert_no_bind_parameter_hint "SELECT 1 -- DATE\n$1"
        end

        def test_keyword_before_another_occurrence_of_the_parameter_gets_no_hint
          assert_no_bind_parameter_hint "SELECT 1 + $1 $1, DATE $1"
        end

        def test_keyword_ending_an_identifier_gets_no_hint
          assert_no_bind_parameter_hint "SELECT foo$DATE $1"
        end

        def test_double_dash_in_quoted_text_on_the_same_line_suppresses_the_hint
          assert_no_bind_parameter_hint "SELECT '--', DATE $1"
          assert_no_bind_parameter_hint "SELECT $$--$$, DATE $1"
        end

        private
          def assert_bind_parameter_hint(&block)
            skip unless Post.lease_connection.prepared_statements

            error = assert_raises(ActiveRecord::StatementInvalid, &block)
            assert_equal ActiveRecord::StatementInvalid, error.class
            assert_instance_of PG::SyntaxError, error.cause
            assert_includes error.message, 'syntax error at or near "$'
            assert_includes error.message, "sanitize_sql_array"
            error
          end

          def assert_no_bind_parameter_hint(sql)
            skip unless Post.lease_connection.prepared_statements

            error = assert_raises(ActiveRecord::StatementInvalid) { Post.lease_connection.select_all(sql, "SQL", [1], preparable: true) }
            assert_includes error.message, 'syntax error at or near "$1"'
            assert_not_includes error.message, "Hint:"
          end

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
