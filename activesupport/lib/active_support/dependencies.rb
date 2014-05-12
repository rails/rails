require 'set'
require 'active_support/core_ext/module/concerning'
require 'active_support/core_ext/module/remove_method'
require 'active_support/core_ext/module/introspection'
require 'active_support/core_ext/string/inflections'

module ActiveSupport
  module Dependencies
    extend self

    def const_missing(const_name)
      require_dependency autoload_path_for(const_name)
    end

    def require_dependency(file_name, message = nil)
      capture_constants(file_name) do
        Kernel.send kernel_mechanism, path_for_file_name(file_name)
      end
    end

    mattr_accessor :autoload_paths
    self.autoload_paths = []

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

    mattr_accessor :loaded_constants
    self.loaded_constants = Set.new

    def capture_constants(namespace)
      const_scope = namespace.safe_constantize || Object
      old_constants = const_scope.local_constants

      yield

      self.loaded_constants |= (const_scope.local_constants - old_constants)
    end

    def kernel_mechanism
      load? ? :load : :require
    end

    def load?
      !!ENV['NO_RELOAD']
    end

    def path_for_file_name(file_name)
      if load?
        file_name.sub(/(\.rb)?\z/, '.rb')
      else
        file_name.sub(/\.rb$/, '')
      end
    end

    def autoload_path_for(const_name)
      file_name = const_name.to_s.underscore

      autoload_paths.find do |root|
        path = File.join(root, file_name)
        return path if File.file? path
      end
    end
  end
end
