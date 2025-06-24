# frozen_string_literal: true


module Rails
  class Railtie
    module Configurable
      extend ActiveSupport::Concern

      module ClassMethods
        delegate :config, to: :instance

        def inherited(base)
          raise "You cannot inherit from a #{superclass.name} child"
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

        private
          def method_missing(...)
            instance.send(...)
          end
      end
    end
  end
end
