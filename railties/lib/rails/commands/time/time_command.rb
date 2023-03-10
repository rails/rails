# frozen_string_literal: true

require "rails/commands/time/helpers"
require "rails/command/helpers/editor"

module Rails
  module Command
    class TimeCommand < Base # :nodoc:
      include Rails::Command::Time::Helpers

      no_commands do
        def help(command_name = nil, *)
          super
          if command_name == "zones"
            say ""
            say self.class.class_usage
          end
        end
      end

      desc "zones [COUNTRY_OR_OFFSET]", "Show names of time zones recognized by the Rails TimeZone class"
      def zones(country_or_offset = nil)
        require_time

        if country_or_offset
          zones, offset = parse_country_or_offset(country_or_offset)
        end
        zones ||= ActiveSupport::TimeZone.all

        display_time_zone_list zones, offset
      end
    end
  end
end
