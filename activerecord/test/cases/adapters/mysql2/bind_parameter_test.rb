# frozen_string_literal: true

require 'cases/helper'
require 'models/topic'

module ActiveRecord
  module ConnectionAdapters
    class Mysql2Adapter
      class BindParameterTest < ActiveRecord::Mysql2TestCase
        fixtures :topics

        def test_update_question_marks
          str       = 'foo?bar'
          x         = Topic.first
          x.title   = str
          x.content = str
          x.save!
          x.reload
          assert_equal str, x.title
          assert_equal str, x.content
        end

        def test_create_question_marks
          str = 'foo?bar'
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
      end
    end
  end
end
