require 'active_support/core_ext/kernel/singleton_class'
require 'active_support/core_ext/module/delegation'

module ActiveSupport
  class Deprecation
    module InstanceDelegator
      def self.included(base)
        base.extend(ClassMethods)
        base.public_class_method :new
      end

      module ClassMethods
        def include(included_module)
          included_module.instance_methods.each { |m| method_added(m) }
          super
        end

        def method_added(method_name)
          singleton_class.delegate(method_name, to: :instance)
        end
      end
    end
  end
end