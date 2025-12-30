# frozen_string_literal: true

require "cases/helper"
require "models/topic"
require "models/post"

module ActiveRecord
  module ConnectionAdapters
    class AbstractMysqlAdapter
      class BindParameterTest < ActiveRecord::AbstractMysqlTestCase
        fixtures :topics, :posts

        def test_update_question_marks
          str       = "foo?bar"
          x         = Topic.first
          x.title   = str
          x.content = str
          x.save!
          x.reload
          assert_equal str, x.title
          assert_equal str, x.content
        end

        def test_create_question_marks
          str = "foo?bar"
          x   = Topic.create!(title: str, content: str)
          x.reload
          assert_equal str, x.title
          assert_equal str, x.content
        end

        def test_update_null_bytes
          str       = "foo\0bar"
          x         = Topic.first
          x.title   = str
          x.content = str
          x.save!
          x.reload
          assert_equal str, x.title
          assert_equal str, x.content
        end

        def test_create_null_bytes
          str = "foo\0bar"
          x   = Topic.create!(title: str, content: str)
          x.reload
          assert_equal str, x.title
          assert_equal str, x.content
        end

        def test_where_with_string_for_string_column_using_bind_parameters
          assert_quoted_as "'Welcome to the weblog'", "Welcome to the weblog", match: 1
        end

        def test_where_with_integer_for_string_column_using_bind_parameters
          assert_quoted_as "'0'", 0
        end

        def test_where_with_float_for_string_column_using_bind_parameters
          assert_quoted_as "'0.0'", 0.0
        end

        def test_where_with_boolean_for_string_column_using_bind_parameters
          assert_quoted_as "'0'", false
        end

        def test_where_with_decimal_for_string_column_using_bind_parameters
          assert_quoted_as "'0.0'", BigDecimal(0)
        end

        def test_where_with_rational_for_string_column_using_bind_parameters
          assert_quoted_as "'0.0'", Rational(0)
        end

        private
          def assert_quoted_as(expected, value, match: 0)
            relation = Post.where("title = ?", value)
            assert_equal(
              %{SELECT `posts`.* FROM `posts` WHERE (title = #{expected})},
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
