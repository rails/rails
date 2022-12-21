# frozen_string_literal: true

require "active_support/string_inquirer"

module ActiveSupport
  class EnvironmentInquirer < StringInquirer # :nodoc:
    # Optimization for the three default environments, so this inquirer doesn't need to rely on
    # the slower delegation through method_missing that StringInquirer would normally entail.
    DEFAULT_ENVIRONMENTS = %w[ development test production ]
    def initialize(env)
      super(env)

      DEFAULT_ENVIRONMENTS.each do |default|
        instance_variable_set :"@#{default}", env == default
      end
    end

    DEFAULT_ENVIRONMENTS.each do |env|
      class_eval "def #{env}?; @#{env}; end"
    end
  end
end
