# frozen_string_literal: true

require 'active_support/deprecation'

ActiveSupport::Deprecation.warn 'You have required `active_support/core_ext/range/include_range`. ' \
'This file will be removed in Rails 6.1. You should require `active_support/core_ext/range/compare_range` ' \
  'instead.'

require 'active_support/core_ext/range/compare_range'
