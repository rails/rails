module ActiveRecord
  module ApplicationConfiguration
    extend ActiveSupport::Concern

    module ClassMethods
      def application_record(klass = nil)
        return ActiveRecord::Base unless klass

        klass = klass.class unless klass.respond_to?(:parents)

        if klass.respond_to?(:application_record)
          klass.application_record
        elsif app_record = klass.parents.detect { |p| p.respond_to?(:application_record) }
          app_record
        else
          ActiveRecord::Base
        end
      end
    end
  end
end
