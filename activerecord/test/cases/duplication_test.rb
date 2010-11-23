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

    def test_clone_persisted
      topic = Topic.first
      cloned = topic.clone
      assert topic.persisted?, 'topic persisted'
      assert cloned.persisted?, 'topic persisted'
      assert !cloned.new_record?, 'topic is not new'
    end

    def test_clone_keeps_frozen
      topic = Topic.first
      topic.freeze

      cloned = topic.clone
      assert cloned.persisted?, 'topic persisted'
      assert !cloned.new_record?, 'topic is not new'
      assert cloned.frozen?, 'topic should be frozen'
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
  end
end
