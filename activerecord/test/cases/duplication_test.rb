require "cases/helper"
require 'models/topic'

module ActiveRecord
  class DuplicationTest < ActiveRecord::TestCase
    fixtures :topics

    def test_dup
      assert !Minimalistic.new.freeze.dup.frozen?
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
      assert cloned.persisted?, 'topic persisted'
      assert !cloned.new_record?, 'topic is not new'
    end

    def test_clone_keeps_frozen
      topic = Topic.first
      topic.freeze

      cloned = topic.clone
      assert cloned.persisted?, 'topic persisted'
      assert !cloned.new_record?, 'topic is not new'
      assert cloned.frozen?, 'topic is frozen'
    end
  end
end
