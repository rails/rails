module Rails
  class Engine
    module Configurable
      def self.included(base)
        base.extend ClassMethods
        base.private_class_method :new
      end

      module ClassMethods
        delegate :middleware, :root, :paths, :to => :config
        delegate :call, :to => :instance

        def config
          @config ||= Engine::Configuration.new(find_root_with_flag("lib"))
        end

        def inherited(base)
          raise "You cannot inherit from a Rails::Engine child"
        end

        def instance
          @instance ||= new
        end
      end

      def config
        self.class.config
      end
    end
  end
end
