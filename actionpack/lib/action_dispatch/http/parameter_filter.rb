# frozen_string_literal: true

require 'active_support/deprecation/constant_accessor'
require 'active_support/parameter_filter'

module ActionDispatch
  module Http
    include ActiveSupport::Deprecation::DeprecatedConstantAccessor
    deprecate_constant 'ParameterFilter', 'ActiveSupport::ParameterFilter',
      message: 'ActionDispatch::Http::ParameterFilter is deprecated and will be removed from Rails 6.1. Use ActiveSupport::ParameterFilter instead.'
  end
end
