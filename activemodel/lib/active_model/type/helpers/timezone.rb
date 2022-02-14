# frozen_string_literal: true

require "active_support/core_ext/time/zones"

module ActiveModel
  module Type
    module Helpers # :nodoc:
      module Timezone # :nodoc:
        def is_utc?
          ::Time.zone_default.nil? || ::Time.zone_default.match?("UTC")
        end

        def default_timezone
          is_utc? ? :utc : :local
        end
      end
    end
  end
end
