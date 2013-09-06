module ActiveRecord
  module ApplicationConfiguration
    extend ActiveSupport::Concern

    module ClassMethods
      def configs_from(application)
        app_model = self

        application.singleton_class.instance_eval do
          define_method(:application_model) { app_model }
        end

        define_singleton_method(:configs_from_application) { application }
      end
    end
  end
end
