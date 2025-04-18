# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "active_record/testing/query_assertions"

module ActiveRecord
  module Assertions
    class QueryAssertionsTest < ActiveSupport::TestCase
      extend AdapterHelper
      include QueryAssertions

      def test_assert_queries_count
        assert_queries_count(1) { Post.first }

        error = assert_raises(Minitest::Assertion) {
          assert_queries_count(2) { Post.first }
        }
        assert_match(/1 instead of 2 queries/, error.message)

        error = assert_raises(Minitest::Assertion) {
          assert_queries_count(0) { Post.first }
        }
        assert_match(/1 instead of 0 queries/, error.message)
      end

      def test_assert_queries_count_any
        assert_queries_count { Post.first }

        assert_raises(Minitest::Assertion, match: "1 or more queries expected") {
          assert_queries_count { }
        }
      end

      def test_assert_no_queries
        assert_no_queries { Post.none }

        assert_raises(Minitest::Assertion, match: "1 instead of 0") {
          assert_no_queries { Post.first }
        }
      end

      def test_assert_queries_match
        assert_queries_match(/ASC LIMIT/i, count: 1) { Post.first }
        assert_queries_match(/ASC LIMIT/i) { Post.first }

        error = assert_raises(Minitest::Assertion) {
          assert_queries_match(/ASC LIMIT/i, count: 2) { Post.first }
        }
        assert_match(/1 instead of 2 queries/, error.message)

        error = assert_raises(Minitest::Assertion) {
          assert_queries_match(/ASC LIMIT/i, count: 0) { Post.first }
        }
        assert_match(/1 instead of 0 queries/, error.message)
      end

      def test_assert_queries_match_with_matcher
        error = assert_raises(Minitest::Assertion) {
          assert_queries_match(/WHERE "posts"."id" = \? LIMIT \?/, count: 1) do
            Post.where(id: 1).first
          end
        }
        assert_match(/0 instead of 1 queries/, error.message)
      end

      def test_assert_queries_match_when_there_are_no_queries
        assert_raises(Minitest::Assertion, match: "1 or more queries expected, but none were executed") do
          assert_queries_match(/something/) { Post.none }
        end
      end

      def test_assert_no_queries_match
        assert_no_queries_match(/something/) { Post.none }

        error = assert_raises(Minitest::Assertion) {
          assert_no_queries_match(/ORDER BY/i) { Post.first }
        }
        assert_match(/1 instead of 0/, error.message)
      end

      def test_assert_no_queries_match_matcher
        assert_raises(Minitest::Assertion, match: "1 instead of 0") do
          assert_no_queries_match(/ORDER BY/i) do
            Post.first
          end
        end
      end

      if current_adapter?(:PostgreSQLAdapter)
        def test_assert_queries_count_include_schema
          Post.columns # load columns
          assert_raises(Minitest::Assertion, match: "1 or more queries expected") do
            assert_queries_count(include_schema: true) { Post.columns }
          end

          Post.reset_column_information
          assert_queries_count(include_schema: true) { Post.columns }
        end

        def test_assert_no_queries_include_schema
          assert_no_queries { Post.none }

          assert_raises(Minitest::Assertion, match: /\d instead of 0/) {
            assert_no_queries { Post.first }
          }

          Post.reset_column_information
          assert_raises(Minitest::Assertion, match: /\d instead of 0/) {
            assert_no_queries(include_schema: true) { Post.columns }
          }
        end

        def test_assert_queries_match_include_schema
          Post.columns # load columns
          assert_raises(Minitest::Assertion, match: "1 or more queries expected") do
            assert_queries_match(/SELECT/i, include_schema: true) { Post.columns }
          end

          Post.reset_column_information
          assert_queries_match(/SELECT/i, include_schema: true) { Post.columns }
        end

        def test_assert_no_queries_match_include_schema
          Post.columns # load columns
          assert_no_queries_match(/SELECT/i, include_schema: true) { Post.columns }

          Post.reset_column_information
          assert_raises(Minitest::Assertion, match: /\d instead of 0/) do
            assert_no_queries_match(/SELECT/i, include_schema: true) { Post.columns }
          end
        end
      end
    end
  end
end
