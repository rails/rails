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
          @changed_attributes.delete(attr) unless field_changed?(attr, old, value)
        else
          old = clone_attribute_value(:read_attribute, attr)
          # Save Time objects as TimeWithZone if time_zone_aware_attributes == true
          old = old.in_time_zone if clone_with_time_zone_conversion_attribute?(attr, old)
          @changed_attributes[attr] = old if field_changed?(attr, old, value)
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

      def field_changed?(attr, old, value)
        if column = column_for_attribute(attr)
          if column.number? && (changes_from_nil_to_empty_string?(column, old, value) ||
                                changes_from_zero_to_string?(old, value))
            value = nil
          else
            value = column.type_cast(value)
          end
        end

        old != value
      end

      def clone_with_time_zone_conversion_attribute?(attr, old)
        old.class.name == "Time" && time_zone_aware_attributes && !self.skip_time_zone_conversion_for_attributes.include?(attr.to_sym)
      end

      def changes_from_nil_to_empty_string?(column, old, value)
        # For nullable numeric columns, NULL gets stored in database for blank (i.e. '') values.
        # Hence we don't record it as a change if the value changes from nil to ''.
        # If an old value of 0 is set to '' we want this to get changed to nil as otherwise it'll
        # be typecast back to 0 (''.to_i => 0)
        column.null && (old.nil? || old == 0) && value.blank?
      end

      def changes_from_zero_to_string?(old, value)
        # For columns with old 0 and value non-empty string
        old == 0 && value.is_a?(String) && value.present? && value != '0'
      end
    end
  end
end
