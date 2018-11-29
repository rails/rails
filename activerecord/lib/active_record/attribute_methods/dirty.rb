# frozen_string_literal: true

require "active_support/core_ext/module/attribute_accessors"

module ActiveRecord
  module AttributeMethods
    module Dirty
      extend ActiveSupport::Concern

      include ActiveModel::Dirty

      included do
        if self < ::ActiveRecord::Timestamp
          raise "You cannot include Dirty after Timestamp"
        end

        class_attribute :partial_writes, instance_writer: false, default: true

        # Attribute methods for "changed in last call to save?"
        attribute_method_affix(prefix: "saved_change_to_", suffix: "?")
        attribute_method_prefix("saved_change_to_")
        attribute_method_suffix("_before_last_save")

        # Attribute methods for "will change if I call save?"
        attribute_method_affix(prefix: "will_save_change_to_", suffix: "?")
        attribute_method_suffix("_change_to_be_saved", "_in_database")
      end

      # <tt>reload</tt> the record and clears changed attributes.
      def reload(*)
        super.tap do
          @previously_changed = ActiveSupport::HashWithIndifferentAccess.new
          @mutations_before_last_save = nil
          @attributes_changed_by_setter = ActiveSupport::HashWithIndifferentAccess.new
          @mutations_from_database = nil
        end
      end

      # Did this attribute change when we last saved? This method can be invoked
      # as +saved_change_to_name?+ instead of <tt>saved_change_to_attribute?("name")</tt>.
      # Behaves similarly to +attribute_changed?+. This method is useful in
      # after callbacks to determine if the call to save changed a certain
      # attribute.
      #
      # ==== Options
      #
      # +from+ When passed, this method will return false unless the original
      # value is equal to the given option
      #
      # +to+ When passed, this method will return false unless the value was
      # changed to the given value
      def saved_change_to_attribute?(attr_name, **options)
        mutations_before_last_save.changed?(attr_name, **options)
      end

      # Returns the change to an attribute during the last save. If the
      # attribute was changed, the result will be an array containing the
      # original value and the saved value.
      #
      # Behaves similarly to +attribute_change+. This method is useful in after
      # callbacks, to see the change in an attribute that just occurred
      #
      # This method can be invoked as +saved_change_to_name+ in instead of
      # <tt>saved_change_to_attribute("name")</tt>
      def saved_change_to_attribute(attr_name)
        mutations_before_last_save.change_to_attribute(attr_name)
      end

      # Returns the original value of an attribute before the last save.
      # Behaves similarly to +attribute_was+. This method is useful in after
      # callbacks to get the original value of an attribute before the save that
      # just occurred
      def attribute_before_last_save(attr_name)
        mutations_before_last_save.original_value(attr_name)
      end

      # Did the last call to +save+ have any changes to change?
      def saved_changes?
        mutations_before_last_save.any_changes?
      end

      # Returns a hash containing all the changes that were just saved.
      def saved_changes
        mutations_before_last_save.changes
      end

      # Alias for +attribute_changed?+
      def will_save_change_to_attribute?(attr_name, **options)
        mutations_from_database.changed?(attr_name, **options)
      end

      # Alias for +attribute_change+
      def attribute_change_to_be_saved(attr_name)
        mutations_from_database.change_to_attribute(attr_name)
      end

      # Alias for +attribute_was+
      def attribute_in_database(attr_name)
        mutations_from_database.original_value(attr_name)
      end

      # Alias for +changed?+
      def has_changes_to_save?
        mutations_from_database.any_changes?
      end

      # Alias for +changes+
      def changes_to_save
        mutations_from_database.changes
      end

      # Alias for +changed+
      def changed_attribute_names_to_save
        mutations_from_database.changed_attribute_names
      end

      # Alias for +changed_attributes+
      def attributes_in_database
        mutations_from_database.changed_values
      end

      private
        def write_attribute_without_type_cast(attr_name, value)
          name = attr_name.to_s
          if self.class.attribute_alias?(name)
            name = self.class.attribute_alias(name)
          end
          result = super(name, value)
          clear_attribute_change(name)
          result
        end

        def _update_record(*)
          affected_rows = partial_writes? ? super(keys_for_partial_write) : super
          changes_applied
          affected_rows
        end

        def _create_record(*)
          id = partial_writes? ? super(keys_for_partial_write) : super
          changes_applied
          id
        end

        def keys_for_partial_write
          changed_attribute_names_to_save & self.class.column_names
        end
    end
  end
end
