# frozen_string_literal: true

module Rails
  module ConsoleMethods
    def self.include(_mod, ...)
      raise_deprecation_warning
      super
    end

    def self.method_added(_method_name)
      raise_deprecation_warning
      super
    end

    def self.raise_deprecation_warning
      Rails.deprecator.warn(<<~MSG, caller_locations(2..2))
        Extending Rails console through `Rails::ConsoleMethods` is deprecated and will be removed in Rails 8.0.
        Please directly use IRB's extension API to add new commands or helpers to the console.
        For more details, please visit: https://github.com/ruby/irb/blob/master/EXTEND_IRB.md
      MSG
    end
  end
end
