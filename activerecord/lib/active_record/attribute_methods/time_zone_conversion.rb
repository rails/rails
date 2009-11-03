module ActiveRecord
  module AttributeMethods
    module TimeZoneConversion
      extend ActiveSupport::Concern

      included do
        cattr_accessor :time_zone_aware_attributes, :instance_writer => false
        self.time_zone_aware_attributes = false

        class_inheritable_accessor :skip_time_zone_conversion_for_attributes, :instance_writer => false
        self.skip_time_zone_conversion_for_attributes = []
      end

      module ClassMethods

        def cache_attribute?(attr_name)
          time_zone_aware?(attr_name) || super
        end

        protected

          def time_zone_aware?(attr_name)
            column = columns_hash[attr_name]
            time_zone_aware_attributes &&
              !skip_time_zone_conversion_for_attributes.include?(attr_name.to_sym) &&
                [:datetime, :timestamp].include?(column.type)
          end

      end
    end
  end
end
