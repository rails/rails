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
          @mutations_before_last_save = nil
          @mutations_from_database = nil
        end
      end

      # Did this attribute change when we last saved?
      #
      # This method is useful in after callbacks to determine if an attribute
      # was changed during the save that triggered the callbacks to run. It can
      # be invoked as +saved_change_to_name?+ instead of
      # <tt>saved_change_to_attribute?("name")</tt>.
      #
      # ==== Options
      #
      # +from+ When passed, this method will return false unless the original
      # value is equal to the given option
      #
      # +to+ When passed, this method will return false unless the value was
      # changed to the given value
      def saved_change_to_attribute?(attr_name, **options)
        mutations_before_last_save.changed?(attr_name.to_s, **options)
      end

      # Returns the change to an attribute during the last save. If the
      # attribute was changed, the result will be an array containing the
      # original value and the saved value.
      #
      # This method is useful in after callbacks, to see the change in an
      # attribute during the save that triggered the callbacks to run. It can be
      # invoked as +saved_change_to_name+ instead of
      # <tt>saved_change_to_attribute("name")</tt>.
      def saved_change_to_attribute(attr_name)
        mutations_before_last_save.change_to_attribute(attr_name.to_s)
      end

      # Returns the original value of an attribute before the last save.
      #
      # This method is useful in after callbacks to get the original value of an
      # attribute before the save that triggered the callbacks to run. It can be
      # invoked as +name_before_last_save+ instead of
      # <tt>attribute_before_last_save("name")</tt>.
      def attribute_before_last_save(attr_name)
        mutations_before_last_save.original_value(attr_name.to_s)
      end

      # Did the last call to +save+ have any changes to change?
      def saved_changes?
        mutations_before_last_save.any_changes?
      end

      # Returns a hash containing all the changes that were just saved.
      def saved_changes
        mutations_before_last_save.changes
      end

      # Will this attribute change the next time we save?
      #
      # This method is useful in validations and before callbacks to determine
      # if the next call to +save+ will change a particular attribute. It can be
      # invoked as +will_save_change_to_name?+ instead of
      # <tt>will_save_change_to_attribute?("name")</tt>.
      #
      # ==== Options
      #
      # +from+ When passed, this method will return false unless the original
      # value is equal to the given option
      #
      # +to+ When passed, this method will return false unless the value will be
      # changed to the given value
      def will_save_change_to_attribute?(attr_name, **options)
        mutations_from_database.changed?(attr_name.to_s, **options)
      end

      # Returns the change to an attribute that will be persisted during the
      # next save.
      #
      # This method is useful in validations and before callbacks, to see the
      # change to an attribute that will occur when the record is saved. It can
      # be invoked as +name_change_to_be_saved+ instead of
      # <tt>attribute_change_to_be_saved("name")</tt>.
      #
      # If the attribute will change, the result will be an array containing the
      # original value and the new value about to be saved.
      def attribute_change_to_be_saved(attr_name)
        mutations_from_database.change_to_attribute(attr_name.to_s)
      end

      # Returns the value of an attribute in the database, as opposed to the
      # in-memory value that will be persisted the next time the record is
      # saved.
      #
      # This method is useful in validations and before callbacks, to see the
      # original value of an attribute prior to any changes about to be
      # saved. It can be invoked as +name_in_database+ instead of
      # <tt>attribute_in_database("name")</tt>.
      def attribute_in_database(attr_name)
        mutations_from_database.original_value(attr_name.to_s)
      end

      # Will the next call to +save+ have any changes to persist?
      def has_changes_to_save?
        mutations_from_database.any_changes?
      end

      # Returns a hash containing all the changes that will be persisted during
      # the next save.
      def changes_to_save
        mutations_from_database.changes
      end

      # Returns an array of the names of any attributes that will change when
      # the record is next saved.
      def changed_attribute_names_to_save
        mutations_from_database.changed_attribute_names
      end

      # Returns a hash of the attributes that will change when the record is
      # next saved.
      #
      # The hash keys are the attribute names, and the hash values are the
      # original attribute values in the database (as opposed to the in-memory
      # values about to be saved).
      def attributes_in_database
        mutations_from_database.changed_values
      end

      private
        def write_attribute_without_type_cast(attr_name, value)
          result = super
          clear_attribute_change(attr_name)
          result
        end

        def _touch_row(attribute_names, time)
          @_touch_attr_names = Set.new(attribute_names)

          affected_rows = super

          if @_skip_dirty_tracking ||= false
            clear_attribute_changes(@_touch_attr_names)
            return affected_rows
          end

          changes = {}
          @attributes.each do |attr_name,_value|
            next if @_touch_attr_names.include?(attr_name)

            if attribute_changed?(attr_name)
              changes[attr_name] = _read_attribute(attr_name)
              _write_attribute(attr_name, attribute_was(attr_name))
              clear_attribute_change(attr_name)
            end
          end

          changes_applied
          changes.each { |attr_name, value| _write_attribute(attr_name, value) }

          affected_rows
        ensure
          @_touch_attr_names, @_skip_dirty_tracking = nil, nil
        end

        def _update_record(attribute_names = attribute_names_for_partial_writes)
          affected_rows = super
          changes_applied
          affected_rows
        end

        def _create_record(attribute_names = attribute_names_for_partial_writes)
          id = super
          changes_applied
          id
        end

        def attribute_names_for_partial_writes
          partial_writes? ? changed_attribute_names_to_save : attribute_names
        end
    end
  end
end
