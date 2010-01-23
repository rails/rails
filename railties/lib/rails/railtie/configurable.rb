module Rails
  class Railtie
    module Configurable
      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        def config
          @config ||= Railtie::Configuration.new
        end

        def inherited(base)
          raise "You cannot inherit from a Rails::Railtie child"
        end
      end

      def config
        self.class.config
      end
    end
  end
end
