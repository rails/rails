# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "active_record/testing/query_assertions"

module ActiveRecord
  module Assertions
    class QueryAssertionsTest < ActiveSupport::TestCase
      include QueryAssertions

      def test_assert_queries
        assert_queries(1) { Post.first }

        error = assert_raises(Minitest::Assertion) {
          assert_queries(2) { Post.first }
        }
        assert_match(/1 instead of 2 queries/, error.message)

        error = assert_raises(Minitest::Assertion) {
          assert_queries(0) { Post.first }
        }
        assert_match(/1 instead of 0 queries/, error.message)
      end

      def test_assert_queries_with_matcher
        error = assert_raises(Minitest::Assertion) {
          assert_queries(1, matcher: /WHERE "posts"."id" = \? LIMIT \?/) do
            Post.where(id: 1).first
          end
        }
        assert_match(/0 instead of 1 queries/, error.message)
      end

      def test_assert_no_queries
        assert_no_queries { Post.none }

        error = assert_raises(Minitest::Assertion) {
          assert_no_queries { Post.first }
        }
        assert_match(/1 instead of 0/, error.message)
      end
    end
  end
end
