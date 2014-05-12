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
      capture_constants FileNamespace.new(path: file_name) do
        Kernel.send kernel_mechanism, normalize_file_name(file_name)
      end
    end

    mattr_accessor :autoload_paths
    self.autoload_paths = []

    def unload!
      loaded_namespaces.each(&:unload!)
      loaded_namespaces.clear
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

    mattr_accessor :loaded_namespaces
    self.loaded_namespaces = Set.new

    def capture_constants(namespace)
      return if loaded_namespaces.include? namespace

      namespace.define_constants! { yield }.map do |constant|
        loaded_namespaces << namespace.embrace(constant)
      end
    end

    def kernel_mechanism
      load? ? :load : :require
    end

    def load?
      !!ENV['NO_RELOAD']
    end

    def normalize_file_name(file_name)
      file_name.sub(/(\.rb)?\z/, load? ? '.rb' : '')
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
