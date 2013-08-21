
module ActiveRecord
  module ReadonlyAttributes
    extend ActiveSupport::Concern

    included do
      class_attribute :_attr_readonly, instance_accessor: false
      self._attr_readonly = []
    end

    module ClassMethods
      # Attributes listed as readonly will be used to create a new record but update operations will
      # ignore these fields.
      def attr_readonly(*attributes)
        self._attr_readonly = Set.new(attributes.map { |a| a.to_s }) + (self._attr_readonly || [])
      end

      # Returns an array of all the attributes that have been specified as readonly.
      def readonly_attributes
        self._attr_readonly
      end
    end
  end
end
