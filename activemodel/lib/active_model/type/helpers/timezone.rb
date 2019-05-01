# frozen_string_literal: true

require "active_support/core_ext/time/zones"

module ActiveModel
  module Type
    module Helpers # :nodoc: all
      module Timezone
        def is_utc?
          ::Time.zone_default.nil? || ::Time.zone_default =~ "UTC"
        end

        def default_timezone
          is_utc? ? :utc : :local
        end
      end
    end
  end
end
