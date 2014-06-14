require 'active_support/core_ext/module/attribute_accessors'

module ActiveRecord
  module AttributeMethods
    module Dirty # :nodoc:
      extend ActiveSupport::Concern

      include ActiveModel::Dirty

      included do
        if self < ::ActiveRecord::Timestamp
          raise "You cannot include Dirty after Timestamp"
        end

        class_attribute :partial_writes, instance_writer: false
        self.partial_writes = true
      end

      # Attempts to +save+ the record and clears changed attributes if successful.
      def save(*)
        if status = super
          changes_applied
        end
        status
      end

      # Attempts to <tt>save!</tt> the record and clears changed attributes if successful.
      def save!(*)
        super.tap do
          changes_applied
        end
      end

      # <tt>reload</tt> the record and clears changed attributes.
      def reload(*)
        super.tap do
          reset_changes
        end
      end

      def initialize_dup(other) # :nodoc:
        super
        init_changed_attributes
      end

      def changed?
        super || changed_in_place.any?
      end

      def changed
        super | changed_in_place
      end

      def attribute_changed?(attr_name, options = {})
        result = super
        # We can't change "from" something in place. Only setters can define
        # "from" and "to"
        result ||= changed_in_place?(attr_name) unless options.key?(:from)
        result
      end

      def changes_applied
        super
        store_original_raw_attributes
      end

      def reset_changes
        super
        original_raw_attributes.clear
      end

      private

      def initialize_internals_callback
        super
        init_changed_attributes
      end

      def init_changed_attributes
        @changed_attributes = nil
        # Intentionally avoid using #column_defaults since overridden defaults (as is done in
        # optimistic locking) won't get written unless they get marked as changed
        self.class.columns.each do |c|
          attr, orig_value = c.name, c.default
          changed_attributes[attr] = orig_value if _field_changed?(attr, orig_value)
        end
      end

      # Wrap write_attribute to remember original attribute value.
      def write_attribute(attr, value)
        attr = attr.to_s

        old_value = old_attribute_value(attr)

        result = super
        store_original_raw_attribute(attr)
        save_changed_attribute(attr, old_value)
        result
      end

      def raw_write_attribute(attr, value)
        attr = attr.to_s

        result = super
        original_raw_attributes[attr] = value
        result
      end

      def save_changed_attribute(attr, old_value)
        if attribute_changed?(attr)
          changed_attributes.delete(attr) unless _field_changed?(attr, old_value)
        else
          changed_attributes[attr] = old_value if _field_changed?(attr, old_value)
        end
      end

      def old_attribute_value(attr)
        if attribute_changed?(attr)
          changed_attributes[attr]
        else
          clone_attribute_value(:read_attribute, attr)
        end
      end

      def _update_record(*)
        partial_writes? ? super(keys_for_partial_write) : super
      end

      def _create_record(*)
        partial_writes? ? super(keys_for_partial_write) : super
      end

      # Serialized attributes should always be written in case they've been
      # changed in place.
      def keys_for_partial_write
        changed
      end

      def _field_changed?(attr, old_value)
        new_value = read_attribute(attr)
        raw_value = read_attribute_before_type_cast(attr)
        column_for_attribute(attr).changed?(old_value, new_value, raw_value)
      end

      def changed_in_place
        self.class.attribute_names.select do |attr_name|
          changed_in_place?(attr_name)
        end
      end

      def changed_in_place?(attr_name)
        type = type_for_attribute(attr_name)
        old_value = original_raw_attribute(attr_name)
        value = read_attribute(attr_name)
        type.changed_in_place?(old_value, value)
      end

      def original_raw_attribute(attr_name)
        original_raw_attributes.fetch(attr_name) do
          read_attribute_before_type_cast(attr_name)
        end
      end

      def original_raw_attributes
        @original_raw_attributes ||= {}
      end

      def store_original_raw_attribute(attr_name)
        type = type_for_attribute(attr_name)
        value = type.type_cast_for_database(read_attribute(attr_name))
        original_raw_attributes[attr_name] = value
      end

      def store_original_raw_attributes
        attribute_names.each do |attr|
          store_original_raw_attribute(attr)
        end
      end
    end
  end
end
