require "active_support/string_inquirer"
require "active_support/basic_object"

module Rails
  module Initializer
    def self.run(&block)
      klass = Class.new(Rails::Application)
      klass.instance_exec(klass.config, &block)
      klass.initialize!
    end
  end

  class DeprecatedConstant < ActiveSupport::BasicObject
    def self.deprecate(old, new)
      constant = self.new(old, new)
      eval "::#{old} = constant"
    end

    def initialize(old, new)
      @old, @new = old, new
      @target = ::Kernel.eval "proc { #{@new} }"
      @warned = false
    end

    def method_missing(meth, *args, &block)
      ::ActiveSupport::Deprecation.warn("#{@old} is deprecated. Please use #{@new}") unless @warned
      @warned = true

      target = @target.call
      if target.respond_to?(meth)
        target.send(meth, *args, &block)
      else
        super
      end
    end
  end

  DeprecatedConstant.deprecate("RAILS_ROOT",           "::Rails.root.to_s")
  DeprecatedConstant.deprecate("RAILS_ENV",            "::Rails.env")
  DeprecatedConstant.deprecate("RAILS_DEFAULT_LOGGER", "::Rails.logger")
end
