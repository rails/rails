# frozen_string_literal: true

require "cases/helper"
require "models/topic"

module ActiveRecord
  module Type
    class TimeTest < ActiveRecord::TestCase
      def test_default_year_is_correct
        expected_time = ::Time.utc(2000, 1, 1, 10, 30, 0)
        topic = Topic.new(bonus_time: { 4 => 10, 5 => 30 })

        assert_equal expected_time, topic.bonus_time
        assert_instance_of ::Time, topic.bonus_time

        topic.save!

        assert_equal expected_time, topic.bonus_time
        assert_instance_of ::Time, topic.bonus_time

        topic.reload

        assert_equal expected_time, topic.bonus_time
        assert_instance_of ::Time, topic.bonus_time
      end
    end
  end
end
