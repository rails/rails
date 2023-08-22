# frozen_string_literal: true

module ActiveSupport
  class Deprecation
    module InstanceDelegator # :nodoc:
      def self.included(base)
        base.extend(ClassMethods)
        base.singleton_class.prepend(OverrideDelegators)
      end

      module ClassMethods # :nodoc:
        MUTEX = Mutex.new
        private_constant :MUTEX

        def include(included_module)
          included_module.instance_methods.each { |m| method_added(m) }
          super
        end

        def method_added(method_name)
          use_instead =
            case method_name
            when :silence, :behavior=, :disallowed_behavior=, :disallowed_warnings=, :silenced=, :debug=
              target = "(defined?(Rails.application.deprecators) ? Rails.application.deprecators : ActiveSupport::Deprecation._instance)"
              "Rails.application.deprecators.#{method_name}"
            when :warn, :deprecate_methods, :gem_name, :gem_name=, :deprecation_horizon, :deprecation_horizon=
              "your own Deprecation object"
            else
              "Rails.application.deprecators[framework].#{method_name} where framework is for example :active_record"
            end
          args = /[^\]]=\z/.match?(method_name) ? "arg" : "..."
          target ||= "ActiveSupport::Deprecation._instance"
          singleton_class.module_eval <<~RUBY, __FILE__, __LINE__ + 1
            def #{method_name}(#{args})
              #{target}.#{method_name}(#{args})
            ensure
              ActiveSupport.deprecator.warn("Calling #{method_name} on ActiveSupport::Deprecation is deprecated and will be removed from Rails (use #{use_instead} instead)")
            end
          RUBY
        end

        def instance
          ActiveSupport.deprecator.warn("ActiveSupport::Deprecation.instance is deprecated (use your own Deprecation object)")
          _instance
        end

        def _instance
          @_instance ||= MUTEX.synchronize { @_instance ||= new }
        end
      end

      module OverrideDelegators # :nodoc:
        def warn(message = nil, callstack = nil)
          callstack ||= caller_locations(2)
          super
        end

        def deprecation_warning(deprecated_method_name, message = nil, caller_backtrace = nil)
          caller_backtrace ||= caller_locations(2)
          super
        end
      end
    end
  end
end
