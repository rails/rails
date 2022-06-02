# frozen_string_literal: true

module TimeZoneTestHelpers
  def with_tz_default(tz = nil)
    old_tz = Time.zone
    Time.zone = tz
    yield
  ensure
    Time.zone = old_tz
  end

  def with_env_tz(new_tz = "US/Eastern")
    old_tz, ENV["TZ"] = ENV["TZ"], new_tz
    yield
  ensure
    old_tz ? ENV["TZ"] = old_tz : ENV.delete("TZ")
  end

  def with_preserve_timezone(value)
    old_preserve_tz = ActiveSupport.to_time_preserves_timezone

    ActiveSupport::Deprecation.silence do
      ActiveSupport.to_time_preserves_timezone = value
    end

    yield
  ensure
    ActiveSupport::Deprecation.silence do
      ActiveSupport.to_time_preserves_timezone = old_preserve_tz
    end
  end

  def with_tz_mappings(mappings)
    old_mappings = ActiveSupport::TimeZone::MAPPING.dup
    ActiveSupport::TimeZone.clear
    ActiveSupport::TimeZone::MAPPING.clear
    ActiveSupport::TimeZone::MAPPING.merge!(mappings)

    yield
  ensure
    ActiveSupport::TimeZone.clear
    ActiveSupport::TimeZone::MAPPING.clear
    ActiveSupport::TimeZone::MAPPING.merge!(old_mappings)
  end

  def with_utc_to_local_returns_utc_offset_times(value)
    old_tzinfo2_format = ActiveSupport.utc_to_local_returns_utc_offset_times
    ActiveSupport.utc_to_local_returns_utc_offset_times = value
    yield
  ensure
    ActiveSupport.utc_to_local_returns_utc_offset_times = old_tzinfo2_format
  end
end
