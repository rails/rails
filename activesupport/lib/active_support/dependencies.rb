require 'set'
require 'active_support/core_ext/module/concerning'
require 'active_support/core_ext/module/remove_method'
require 'active_support/core_ext/module/introspection'
require 'active_support/core_ext/string/inflections'

module ActiveSupport
  module Dependencies
    extend self

    def const_missing(const_name)
      require_dependency path_for_const_name(const_name)
    end

    def require_dependency(file_name, message = nil)
      constant_watcher.capture_constants(file_name) do
        Kernel.send kernel_mechanism, mechanism_aware_file_name(file_name)
      end
    end

    private

    Module.concerning :ConstMissingReplacement do
      redefine_method :const_missing do |const_name|
        Dependencies.const_missing const_name
      end
    end

    Object.concerning :DependencyRequires do
      def require_dependency(file_name, message = "No such file to load -- %s")
        Dependencies.require_dependency(file_name, message)
      end
    end

    # Could be mattr_accessor instead
    def constant_watcher
      @@constant_watcher ||= ConstantWatcher.new
    end

    class ConstantWatcher
      attr_accessor :paths, :loaded_constants

      def initialize
        @paths = Set.new
        @loaded_constants = Set.new
      end

      def capture_constants(namespace)
        const_scope = namespace.constantize
        old_constants = const_scope.local_constants

        yield

        loaded_constants |= Set.new(const_scope.local_constants - old_constants)
      end
    end

    def kernel_mechanism
      load? ? :load : :require
    end

    def load?
      !ENV['NO_RELOAD']
    end

    # horrible name...
    def mechanism_aware_file_name(file_name)
      if load?
        file_name.sub(/(\.rb)?\z/, '.rb')
      else
        file_name.sub(/\.rb$/, '')
      end
    end

    def path_for_const_name(const_name)
      const_name.to_s.underscore
    end
  end
end
