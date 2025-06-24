# frozen_string_literal: true

require "helper"

class TimeWithZoneSerializerTest < ActiveSupport::TestCase
  test "#deserialize preserves serialized time zone" do
    time_zone_before = Time.zone

    Time.zone = "America/Los_Angeles"
    time_with_zone = Time.parse("08:00").in_time_zone

    assert_equal "America/Los_Angeles", time_with_zone.time_zone.tzinfo.name

    serialized = ActiveJob::Serializers::TimeWithZoneSerializer.serialize(time_with_zone)
    Time.zone = "Europe/London"
    deserialized = ActiveJob::Serializers::TimeWithZoneSerializer.deserialize(serialized)

    assert_equal "America/Los_Angeles", deserialized.time_zone.tzinfo.name
    assert_equal time_with_zone, deserialized
  ensure
    Time.zone = time_zone_before
  end
end
