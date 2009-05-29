require 'active_support/dependency_module'

module ActiveSupport
  module Concern
    include DependencyModule

    def append_features(base)
      if super
        base.extend const_get("ClassMethods") if const_defined?("ClassMethods")
        base.send :include, const_get("InstanceMethods") if const_defined?("InstanceMethods")
        base.class_eval(&@_included_block) if instance_variable_defined?("@_included_block")
      end
    end

    def included(base = nil, &block)
      if base.nil?
        @_included_block = block
      else
        super
      end
    end

    alias_method :include, :depends_on
  end
end
