module ActiveRecord
  module ApplicationConfiguration
    extend ActiveSupport::Concern

    module ClassMethods
      def application_record(klass = nil)
        return base_app_record unless klass

        klass = klass.class unless klass.respond_to?(:parents)

        if klass.respond_to?(:application_record)
          klass.application_record
        elsif app_record = klass.parents.detect { |p| p.respond_to?(:application_record) }
          app_record
        else
          base_app_record
        end
      end

      private

        def base_app_record
          @base_app_record ||= defined?(ApplicationRecord) ? ApplicationRecord : ActiveRecord::Base
        end
    end
  end
end
