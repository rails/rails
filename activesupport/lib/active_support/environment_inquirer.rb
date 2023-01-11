# frozen_string_literal: true

require "active_support/string_inquirer"
require "active_support/core_ext/object/inclusion"

module ActiveSupport
  class EnvironmentInquirer < StringInquirer # :nodoc:
    # Optimization for the three default environments, so this inquirer doesn't need to rely on
    # the slower delegation through method_missing that StringInquirer would normally entail.
    DEFAULT_ENVIRONMENTS = %w[ development test production ]

    # Environments that'll respond true for #local?
    LOCAL_ENVIRONMENTS = %w[ development test ]

    def initialize(env)
      raise(ArgumentError, "'local' is a reserved environment name") if env == "local"

      super(env)

      DEFAULT_ENVIRONMENTS.each do |default|
        instance_variable_set :"@#{default}", env == default
      end

      @local = in? LOCAL_ENVIRONMENTS
    end

    DEFAULT_ENVIRONMENTS.each do |env|
      class_eval <<~RUBY, __FILE__, __LINE__ + 1
        def #{env}?
          @#{env}
        end
      RUBY
    end

    # Returns true if we're in the development or test environment.
    def local?
      @local
    end
  end
end
