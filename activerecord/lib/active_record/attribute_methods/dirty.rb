require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/object/blank'

module ActiveRecord
  module AttributeMethods
    module Dirty
      extend ActiveSupport::Concern
      include ActiveModel::Dirty
      include AttributeMethods::Write

      included do
        if self < ::ActiveRecord::Timestamp
          raise "You cannot include Dirty after Timestamp"
        end

        class_attribute :partial_updates
        self.partial_updates = true
      end

      # Attempts to +save+ the record and clears changed attributes if successful.
      def save(*) #:nodoc:
        if status = super
          @previously_changed = changes
          @changed_attributes.clear
        elsif IdentityMap.enabled?
          IdentityMap.remove(self)
        end
        status
      end

      # Attempts to <tt>save!</tt> the record and clears changed attributes if successful.
      def save!(*) #:nodoc:
        super.tap do
          @previously_changed = changes
          @changed_attributes.clear
        end
      rescue
        IdentityMap.remove(self) if IdentityMap.enabled?
        raise
      end

      # <tt>reload</tt> the record and clears changed attributes.
      def reload(*) #:nodoc:
        super.tap do
          @previously_changed.clear
          @changed_attributes.clear
        end
      end

    private
      # Wrap write_attribute to remember original attribute value.
      def write_attribute(attr, value)
        attr = attr.to_s

        # The attribute already has an unsaved change.
        if attribute_changed?(attr)
          old = @changed_attributes[attr]
          @changed_attributes.delete(attr) unless _field_changed?(attr, old, value)
        else
          old = clone_attribute_value(:read_attribute, attr)
          # Save Time objects as TimeWithZone if time_zone_aware_attributes == true
          old = old.in_time_zone if clone_with_time_zone_conversion_attribute?(attr, old)
          @changed_attributes[attr] = old if _field_changed?(attr, old, value)
        end

        # Carry on.
        super(attr, value)
      end

      def update(*)
        if partial_updates?
          # Serialized attributes should always be written in case they've been
          # changed in place.
          super(changed | (attributes.keys & self.class.serialized_attributes.keys))
        else
          super
        end
      end

      def _field_changed?(attr, old, value)
        if column = column_for_attribute(attr)
          # We consider the field changed if the new value after type-casting is different from the old value
          value = column.type_cast(column.number? ? type_cast_for_num(value) : value)
        end

        old != value
      end

      def clone_with_time_zone_conversion_attribute?(attr, old)
        old.class.name == "Time" && time_zone_aware_attributes && !self.skip_time_zone_conversion_for_attributes.include?(attr.to_sym)
      end

      #If column is numerical, then casts the Ruby value to something appropriate for writing into a numerical column.
      def type_cast_for_num(value)
        if value == false
          0
        elsif value == true
          1
        elsif value.is_a?(String) && value.blank?
          nil
        else
          value
        end
      end
    end
  end
end
