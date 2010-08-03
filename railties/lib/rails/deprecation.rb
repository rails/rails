require "active_support/string_inquirer"
require "active_support/basic_object"

module Rails
  class DeprecatedConstant < ActiveSupport::BasicObject
    def self.deprecate(old, new)
      constant = self.new(old, new)
      eval "::#{old} = constant"
    end

    def initialize(old, new)
      @old, @new = old, new
      @target = eval "proc { #{new} }"
      @warned = false
    end

    def method_missing(meth, *args, &block)
      ActiveSupport::Deprecation.warn("#{@old} is deprecated. Please use #{@new}") unless @warned
      @warned = true
      @target.call.send(meth, *args, &block)
    end
  end

  DeprecatedConstant.deprecate("RAILS_ROOT",           "Rails.root")
  DeprecatedConstant.deprecate("RAILS_ENV",            "Rails.env")
  DeprecatedConstant.deprecate("RAILS_DEFAULT_LOGGER", "Rails.logger")
end
