# frozen_string_literal: true

module ActiveSupport
  extend ActiveSupport::Autoload

  autoload :Duration
  autoload :TimeWithZone
  autoload :TimeZone
end

require "date"
require "time"

require "active_support/core_ext/time"
require "active_support/core_ext/date"
require "active_support/core_ext/date_time"

require "active_support/core_ext/integer/time"
require "active_support/core_ext/numeric/time"

require "active_support/core_ext/string/conversions"
require "active_support/core_ext/string/zones"
