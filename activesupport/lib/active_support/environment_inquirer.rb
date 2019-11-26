# frozen_string_literal: true

module ActiveSupport
  # This is a special case of StringInquirer that defines the three default
  # environments at construction time based on the environment string.
  class EnvironmentInquirer < StringInquirer
    DEFAULT_ENVIRONMENTS = ["development", "test", "production"]
    def initialize(env)
      super(env)

      DEFAULT_ENVIRONMENTS.each do |default_env|
        singleton_class.define_method(:"#{env}?", (env == default_env).method(:itself))
      end
    end
  end
end
