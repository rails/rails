# frozen_string_literal: true

module Rails
  module ConsoleMethods
    def self.include(mod, ...)
      raise_deprecation_warning(mod)
      super
    end

    def self.method_added(method_name)
      raise_deprecation_warning(method_name)
      super
    end

    def self.raise_deprecation_warning(offender)
      Rails.deprecator.warn(<<~MSG, caller_locations(1..1))
        Extending Rails console through `Rails::ConsoleMethods` is deprecated and will be removed in Rails 7.3.
        Please directly use IRB's extension API to add new commands or helpers to the console.
        For more details, please visit: https://github.com/ruby/irb/blob/master/EXTEND_IRB.md

        Called via `#{offender}`
      MSG
    end
  end
end
