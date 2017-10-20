# frozen_string_literal: true

require "cases/helper"
require "models/topic"

module ActiveRecord
  class CloneTest < ActiveRecord::TestCase
    fixtures :topics

    def test_persisted
      topic = Topic.first
      cloned = topic.clone
      assert topic.persisted?, "topic persisted"
      assert cloned.persisted?, "topic persisted"
      assert !cloned.new_record?, "topic is not new"
    end

    def test_stays_frozen
      topic = Topic.first
      topic.freeze

      cloned = topic.clone
      assert cloned.persisted?, "topic persisted"
      assert !cloned.new_record?, "topic is not new"
      assert cloned.frozen?, "topic should be frozen"
    end

    def test_shallow
      topic = Topic.first
      cloned = topic.clone
      topic.author_name = "Aaron"
      assert_equal "Aaron", cloned.author_name
    end

    def test_freezing_a_cloned_model_does_not_freeze_clone
      cloned = Topic.new
      clone = cloned.clone
      cloned.freeze
      assert_not clone.frozen?
    end
  end
end
