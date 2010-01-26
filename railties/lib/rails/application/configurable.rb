module Rails
  class Application
    module Configurable
      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        def inherited(base)
          raise "You cannot inherit from a Rails::Application child"
        end
      end

      def config
        @config ||= Application::Configuration.new(self.class.find_root_with_flag("config.ru", Dir.pwd))
      end
    end
  end
end