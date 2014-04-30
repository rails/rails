require 'active_support/core_ext/module/concerning'

module ActiveSupport
  module Dependencies

    Module.concerning :ConstMissingReplacement do
      def self.append_features(base)
        base.send :remove_method, :const_missing

        super
      end

      def const_missing(const_name)
        Dependencies.require_named_dependency const_name
      end
    end

    Object.concerning :DependencyRequires do
      def require_dependency(file_name, message = "No such file to load -- %s")
        Dependencies.require_dependency(file_name, message)
      end
    end

    def require_dependency(file_name, message)
      constant_watcher.capture_constants do
        Kernel.send kernel_mechanism, mechanism_aware_file_name(file_name)
      end
    end

    def require_named_dependency(const_name)
      require_dependency path_for_const_name(const_name)
    end

    private

    # Could be mattr_accessor instead
    def constant_watcher
      @@constant_watcher ||= ConstantWatcher.new
    end

    class ConstantWatcher
      # how can I watch/keep-track-of the constants in a simple and hopefully easy to understand way?
      def initialize
        # data structure here plz
      end

      def capture_constants
        begin
          yield
        rescue NameError
          # later!
        end
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
      file_name = normalize_const_name(const_name)
      normalize_path(file_name)
    end
  end
end