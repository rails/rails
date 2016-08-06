require "active_support/concern"

module Rails
  class Railtie
    module Configurable
      extend ActiveSupport::Concern

      module ClassMethods
        delegate :config, to: :instance

        def inherited(base)
          raise "You cannot inherit from a #{self.superclass.name} child"
        end

        def instance
          @instance ||= new
        end

        def respond_to?(*args)
          super || instance.respond_to?(*args)
        end

        def configure(&block)
          class_eval(&block)
        end

        protected

        def method_missing(*args, &block)
          instance.send(*args, &block)
        end
      end
    end
  end
end
