require "cases/helper"
require 'models/topic'

module ActiveRecord
  class DuplicationTest < ActiveRecord::TestCase
    fixtures :topics

    def test_dup
      assert !Topic.new.freeze.dup.frozen?
    end

    def test_dup_not_persisted
      topic = Topic.first
      duped = topic.dup

      assert !duped.persisted?, 'topic not persisted'
      assert duped.new_record?, 'topic is new'
    end

    def test_dup_has_no_id
      topic = Topic.first
      duped = topic.dup
      assert_nil duped.id
    end

    def test_dup_with_modified_attributes
      topic = Topic.first
      topic.author_name = 'Aaron'
      duped = topic.dup
      assert_equal 'Aaron', duped.author_name
    end

    def test_dup_with_changes
      topic = Topic.first
      topic.author_name = 'Aaron'
      duped = topic.dup
      assert_equal topic.changes, duped.changes
    end

    def test_dup_topics_are_independent
      topic = Topic.first
      topic.author_name = 'Aaron'
      duped = topic.dup

      duped.author_name = 'meow'

      assert_not_equal topic.changes, duped.changes
    end

    def test_dup_attributes_are_independent
      topic = Topic.first
      duped = topic.dup

      duped.author_name = 'meow'
      topic.author_name = 'Aaron'

      assert_equal 'Aaron', topic.author_name
      assert_equal 'meow', duped.author_name
    end
  end
end
