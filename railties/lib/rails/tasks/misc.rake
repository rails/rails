# frozen_string_literal: true

namespace :time do
  desc "List all time zones, list by two-letter country code (`bin/rails time:zones[US]`), or list by UTC offset (`bin/rails time:zones[-8]`)"
  task :zones, :country_or_offset do |t, args|
    zones, offset = ActiveSupport::TimeZone.all, nil

    if country_or_offset = args[:country_or_offset]
      begin
        zones = ActiveSupport::TimeZone.country_zones(country_or_offset)
      rescue TZInfo::InvalidCountryCode
        offset = country_or_offset
      end
    end

    build_time_zone_list zones, offset
  end

  namespace :zones do
    # desc 'Display all time zones, also available: time:zones:us, time:zones:local -- filter with OFFSET parameter, e.g., OFFSET=-6'
    task :all do
      build_time_zone_list ActiveSupport::TimeZone.all
    end

    # desc 'Display names of US time zones recognized by the Rails TimeZone class, grouped by offset. Results can be filtered with optional OFFSET parameter, e.g., OFFSET=-6'
    task :us do
      build_time_zone_list ActiveSupport::TimeZone.us_zones
    end

    # desc 'Display names of time zones recognized by the Rails TimeZone class with the same offset as the system local time'
    task :local do
      require "active_support"
      require "active_support/time"

      jan_offset = Time.now.beginning_of_year.utc_offset
      jul_offset = Time.now.beginning_of_year.change(month: 7).utc_offset
      offset = jan_offset < jul_offset ? jan_offset : jul_offset

      build_time_zone_list(ActiveSupport::TimeZone.all, offset)
    end

    # to find UTC -06:00 zones, OFFSET can be set to either -6, -6:00 or 21600
    def build_time_zone_list(zones, offset = ENV["OFFSET"])
      require "active_support"
      require "active_support/time"
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
          puts "\n* UTC #{zone.formatted_offset} *" unless zone.utc_offset == previous_offset
          puts zone.name
          previous_offset = zone.utc_offset
        end
      end
      puts "\n"
    end
  end
end
