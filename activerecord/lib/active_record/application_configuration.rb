module ActiveRecord
  module ApplicationConfiguration
    extend ActiveSupport::Concern

    module ClassMethods
      def configs_from(mod)
        app_model = self

        mod.singleton_class.instance_eval do
          define_method(:application_model) { app_model }
        end

        define_singleton_method(:configs_from_application) { application }
      end

      def application_model(klass = nil)
        return ActiveRecord::Base unless klass

        klass = klass.class unless klass.respond_to?(:parents)

        if klass.respond_to?(:application_model)
          klass.application_model
        elsif app_model = klass.parents.detect { |p| p.respond_to?(:application_model) }
          app_model
        else
          ActiveRecord::Base
        end
      end
    end
  end
end
