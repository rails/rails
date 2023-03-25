# frozen_string_literal: true

module Rails
  module Command
    module Time # :nodoc:
      module Helpers
        private
          def parse_country_or_offset(country_or_offset)
            [ActiveSupport::TimeZone.country_zones(country_or_offset), ENV["OFFSET"]]
          rescue TZInfo::InvalidCountryCode
            [nil, country_or_offset]
          end

          # to find UTC -06:00 zones, OFFSET can be set to either -6, -6:00 or 21600
          def display_time_zone_list(zones, offset = ENV["OFFSET"])
            if offset
              offset = if offset.to_s.match(/(\+|-)?(\d+):(\d+)/)
                sign = $1 == "-" ? -1 : 1
                hours, minutes = $2.to_f, $3.to_f
                ((hours * 3600) + (minutes.to_f * 60)) * sign
              elsif offset.to_f.abs <= 13
                offset.to_f * 3600
              else
                offset.to_f
              end
            end
            previous_offset = nil
            zones.each do |zone|
              if offset.nil? || offset == zone.utc_offset
                say "\n* UTC #{zone.formatted_offset} *" unless zone.utc_offset == previous_offset
                say zone.name
                previous_offset = zone.utc_offset
              end
            end
            say "\n"
          end

          def require_time
            require "active_support"
            require "active_support/time"
          end
      end
    end
  end
end
