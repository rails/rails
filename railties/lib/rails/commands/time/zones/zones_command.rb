# frozen_string_literal: true

require "rails/commands/time/time_command"

module Rails
  module Command
    module Time
      class ZonesCommand < Base # :nodoc:
        include Rails::Command::Time::Helpers

        def self.printing_commands
          []
        end

        desc "all", "Display all time zones. Filter resuls with optional OFFSET parameter, e.g., OFFSET=-6"
        def all(country_or_offset = nil)
          require_time

          if country_or_offset
            zones, offset = parse_country_or_offset(country_or_offset)
          end
          zones ||= ActiveSupport::TimeZone.all

          display_time_zone_list zones, offset
        end

        desc "us", "Display names of US time zones recognized by the Rails TimeZone class, grouped by offset. Filter results with optional OFFSET parameter, e.g., OFFSET=-6"
        def us(offset = nil)
          require_time

          if offset
            _, offset = parse_country_or_offset(offset)
          end
          zones = ActiveSupport::TimeZone.us_zones

          display_time_zone_list zones, offset
        end

        desc "local", "Display names of time zones recognized by the Rails TimeZone class with the same offset as the system local time"
        def local
          require_time

          jan_offset = ::Time.now.beginning_of_year.utc_offset
          jul_offset = ::Time.now.beginning_of_year.change(month: 7).utc_offset
          offset = jan_offset < jul_offset ? jan_offset : jul_offset

          display_time_zone_list(ActiveSupport::TimeZone.all, offset)
        end
      end
    end
  end
end
