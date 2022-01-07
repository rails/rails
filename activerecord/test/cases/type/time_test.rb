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

    class TimeSerializationTest < ActiveRecord::TestCase

      def setup
        @old_tz = ::Time.zone
        ::Time.zone = "America/Chicago"
      end

      def test_preserves_wrapped_value_class_of_ruby_time

        inner_time = ActiveRecord::Type::Time::Value.new(::Time.new(2000, 1, 1, 10, 30, 0))
        inner_twz  = ActiveRecord::Type::Time::Value.new(::Time.zone.local(2000, 1, 1, 10, 30, 0))
        materialized = ::YAML.load(::YAML.dump(inner_time))

        assert_instance_of ::Time, materialized.__getobj__
      end

      ##
      #  The semantics are different between ::Time and TimeWithZone but there
      #  it is probably important to preserve them because of existing data that
      #  has already been stored
      def test_preserves_wrapped_value_class_of_time_with_zone
        skip("This behaviour will change / go away")
        inner_twz  = ActiveRecord::Type::Time::Value.new(::Time.zone.local(2000, 1, 1, 10, 30, 0))
        materialized = ::YAML.load(::YAML.dump(inner_twz))
        assert_instance_of ::ActiveSupport::TimeWithZone, materialized
      end

      def test_loads_legacy_data_into_new_memory_representation
        legacy_serialized_data = <<-YAML
--- !ruby/object:ActiveSupport::TimeWithZone
utc: 2000-01-01 16:30:00.000000000 Z
zone: !ruby/object:ActiveSupport::TimeZone
  name: America/Chicago
time: 2000-01-01 10:30:00.000000000 Z
YAML

        materialized = ::YAML.load(legacy_serialized_data)
        assert_respond_to materialized, :__getobj__, "If materialized object is properly created it will be a DelegateClass"
        assert_instance_of ::Time, materialized.__getobj__
      end

      def teardown
        ::Time.zone = @old_tz
      end
    end
  end
end
