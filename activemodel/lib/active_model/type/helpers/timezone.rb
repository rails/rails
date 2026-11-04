# frozen_string_literal: true

require "active_support/core_ext/time/zones"

module ActiveModel
  module Type
    module Helpers # :nodoc: all
      module Timezone
        def is_utc?
          if default = ::Time.zone_default
            default.name == "UTC"
          else
            true
          end
        end

        def default_timezone
          is_utc? ? :utc : :local
        end
      end
    end
  end
end
