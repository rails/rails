require "cases/helper"
require 'models/topic'

module ActiveRecord
  class CloneTest < ActiveRecord::TestCase
    fixtures :topics

    def test_persisted
      topic = Topic.order(:id).first
      cloned = topic.clone
      assert topic.persisted?, 'topic persisted'
      assert cloned.persisted?, 'topic persisted'
      assert !cloned.new_record?, 'topic is not new'
    end

    def test_stays_frozen
      topic = Topic.order(:id).first
      topic.freeze

      cloned = topic.clone
      assert cloned.persisted?, 'topic persisted'
      assert !cloned.new_record?, 'topic is not new'
      assert cloned.frozen?, 'topic should be frozen'
    end

    def test_shallow
      topic = Topic.order(:id).first
      cloned = topic.clone
      topic.author_name = 'Aaron'
      assert_equal 'Aaron', cloned.author_name
    end
  end
end
