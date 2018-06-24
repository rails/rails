# frozen_string_literal: true

require "active_support/duration"
require "active_support/core_ext/numeric/time"
require "active_support/deprecation"

ActiveSupport::Deprecation.warn "You have required `active_support/core_ext/integer/time`. " \
"This file will be removed in Rails 6.1. You should require `active_support/core_ext/numeric/time` " \
  "instead."
