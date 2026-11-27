# frozen_string_literal: true

require "active_support/core_ext/module/attribute_accessors"

module ActiveRecord
  module AttributeMethods
    # Active Record Attribute Methods \Dirty
    # ======================================
    #
    # Provides a way to track changes in your Active Record models. It adds all
    # methods from ActiveModel::Dirty and adds database-specific methods.
    #
    # A newly created `Person` object is unchanged:
    #
    # ```
    # class Person < ActiveRecord::Base
    # end
    #
    # person = Person.create(name: "Allison")
    # person.changed? # => false
    # ```
    #
    # Change the name:
    #
    # ```
    # person.name = 'Alice'
    # person.name_in_database          # => "Allison"
    # person.will_save_change_to_name? # => true
    # person.name_change_to_be_saved   # => ["Allison", "Alice"]
    # person.changes_to_save           # => {"name"=>["Allison", "Alice"]}
    # ```
    #
    # Save the changes:
    #
    # ```
    # person.save
    # person.name_in_database        # => "Alice"
    # person.saved_change_to_name?   # => true
    # person.saved_change_to_name    # => ["Allison", "Alice"]
    # person.name_before_last_save   # => "Allison"
    # ```
    #
    # Similar to ActiveModel::Dirty, methods can be invoked as
    # `saved_change_to_name?` or by passing an argument to the generic method
    # `saved_change_to_attribute?("name")`.
    module Dirty
      extend ActiveSupport::Concern

      include ActiveModel::Dirty

      included do
        if self < ::ActiveRecord::Timestamp
          raise "You cannot include Dirty after Timestamp"
        end

        class_attribute :partial_updates, instance_writer: false, default: true
        class_attribute :partial_inserts, instance_writer: false, default: true

        # Attribute methods for "changed in last call to save?"
        attribute_method_affix(prefix: "saved_change_to_", suffix: "?", parameters: "**options")
        attribute_method_prefix("saved_change_to_", parameters: false)
        attribute_method_suffix("_before_last_save", parameters: false)

        # Attribute methods for "will change if I call save?"
        attribute_method_affix(prefix: "will_save_change_to_", suffix: "?", parameters: "**options")
        attribute_method_suffix("_change_to_be_saved", "_in_database", parameters: false)
      end

      # `reload` the record and clears changed attributes.
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
      # be invoked as `saved_change_to_name?` instead of
      # `saved_change_to_attribute?("name")`.
      #
      # #### Options
      #
      # `from`
      # :   When specified, this method will return false unless the original
      # value is equal to the given value.
      #
      # `to`
      # :   When specified, this method will return false unless the value will be
      # changed to the given value.
      def saved_change_to_attribute?(attr_name, **options)
        attr_name = attr_name.name if attr_name.is_a?(Symbol)
        mutations_before_last_save.changed?(attr_name.to_s, **options)
      end

      # Returns the change to an attribute during the last save. If the
      # attribute was changed, the result will be an array containing the
      # original value and the saved value.
      #
      # This method is useful in after callbacks, to see the change in an
      # attribute during the save that triggered the callbacks to run. It can be
      # invoked as `saved_change_to_name` instead of
      # `saved_change_to_attribute("name")`.
      def saved_change_to_attribute(attr_name)
        attr_name = attr_name.name if attr_name.is_a?(Symbol)
        mutations_before_last_save.change_to_attribute(attr_name.to_s)
      end

      # Returns the original value of an attribute before the last save.
      #
      # This method is useful in after callbacks to get the original value of an
      # attribute before the save that triggered the callbacks to run. It can be
      # invoked as `name_before_last_save` instead of
      # `attribute_before_last_save("name")`.
      def attribute_before_last_save(attr_name)
        attr_name = attr_name.name if attr_name.is_a?(Symbol)
        mutations_before_last_save.original_value(attr_name.to_s)
      end

      # Did the last call to `save` have any changes to change?
      #: () -> bool
      def saved_changes?
        mutations_before_last_save.any_changes?
      end

      # Returns a hash containing all the changes that were just saved.
      #: () -> (ActiveSupport::HashWithIndifferentAccess | Hash[String, [ untyped, untyped ]])
      def saved_changes
        mutations_before_last_save.changes
      end

      # Returns a hash of the changes that every save of the record made in the
      # current transaction, or in the last transaction once it has finished.
      #
      # It is #saved_changes merged over every save in the transaction: each
      # change is an array of the value before the first save that changed the
      # attribute and the value after the last save. Unlike #saved_changes,
      # which only contains the changes of the last save, this is useful in
      # `after_commit` callbacks, which run once for the whole transaction:
      #
      # ```
      # class Person < ActiveRecord::Base
      #   after_commit :send_confirmation_email, if: -> { transaction_changes.key?("email") }
      # end
      #
      # Person.transaction do
      #   person.update!(email: "alice@example.com")
      #   person.update!(name: "Alice")
      # end
      #
      # person.saved_changes.key?("email")       # => false
      # person.transaction_changes.key?("email") # => true
      # ```
      #
      # Attributes that the transaction saved back to their original value are
      # not included, and neither are changes that are not saved yet (see
      # #changes_to_save). The changes are kept when the record is reloaded,
      # and are replaced when the record joins another transaction. After a
      # rollback they are empty, but `after_rollback` callbacks see the changes
      # that the transaction attempted to save.
      #: () -> (ActiveSupport::HashWithIndifferentAccess | Hash[String, [ untyped, untyped ]])
      def transaction_changes
        return {} unless @_transaction_last_save_mutations

        merge_saved_changes(@_transaction_saved_changes&.transform_values(&:dup), @_transaction_last_save_mutations.changes)
      end

      # Will this attribute change the next time we save?
      #
      # This method is useful in validations and before callbacks to determine
      # if the next call to `save` will change a particular attribute. It can be
      # invoked as `will_save_change_to_name?` instead of
      # `will_save_change_to_attribute?("name")`.
      #
      # #### Options
      #
      # `from`
      # :   When specified, this method will return false unless the original
      # value is equal to the given value.
      #
      # `to`
      # :   When specified, this method will return false unless the value will be
      # changed to the given value.
      def will_save_change_to_attribute?(attr_name, **options)
        attr_name = attr_name.name if attr_name.is_a?(Symbol)
        mutations_from_database.changed?(attr_name.to_s, **options)
      end

      # Returns the change to an attribute that will be persisted during the
      # next save.
      #
      # This method is useful in validations and before callbacks, to see the
      # change to an attribute that will occur when the record is saved. It can
      # be invoked as `name_change_to_be_saved` instead of
      # `attribute_change_to_be_saved("name")`.
      #
      # If the attribute will change, the result will be an array containing the
      # original value and the new value about to be saved.
      def attribute_change_to_be_saved(attr_name)
        attr_name = attr_name.name if attr_name.is_a?(Symbol)
        mutations_from_database.change_to_attribute(attr_name.to_s)
      end

      # Returns the value of an attribute in the database, as opposed to the
      # in-memory value that will be persisted the next time the record is
      # saved.
      #
      # This method is useful in validations and before callbacks, to see the
      # original value of an attribute prior to any changes about to be
      # saved. It can be invoked as `name_in_database` instead of
      # `attribute_in_database("name")`.
      def attribute_in_database(attr_name)
        attr_name = attr_name.name if attr_name.is_a?(Symbol)
        mutations_from_database.original_value(attr_name.to_s)
      end

      # Will the next call to `save` have any changes to persist?
      #: () -> bool
      def has_changes_to_save?
        mutations_from_database.any_changes?
      end

      # Returns a hash containing all the changes that will be persisted during
      # the next save.
      #: () -> ActiveSupport::HashWithIndifferentAccess
      def changes_to_save
        mutations_from_database.changes
      end

      # Returns an array of the names of any attributes that will change when
      # the record is next saved.
      #: () -> Array[String]
      def changed_attribute_names_to_save
        mutations_from_database.changed_attribute_names
      end

      # Returns a hash of the attributes that will change when the record is
      # next saved.
      #
      # The hash keys are the attribute names, and the hash values are the
      # original attribute values in the database (as opposed to the in-memory
      # values about to be saved).
      #: () -> ActiveSupport::HashWithIndifferentAccess
      def attributes_in_database
        mutations_from_database.changed_values
      end

      private
        def init_internals
          super
          @mutations_before_last_save = nil
          @mutations_from_database = nil
          @_touch_attr_names = nil
          @_skip_dirty_tracking = nil
          @_transaction_saved_changes = nil
          @_transaction_last_save_mutations = nil
        end

        def remember_transaction_changes
          if @_transaction_last_save_mutations
            @_transaction_saved_changes = merge_saved_changes(@_transaction_saved_changes, @_transaction_last_save_mutations.changes)
          end
          @_transaction_last_save_mutations = @mutations_before_last_save
        end

        def merge_saved_changes(changes, saved_changes)
          return saved_changes unless changes

          changes.merge(saved_changes) do |attr_name, (original_value, _), (_, value)|
            [original_value, value] if @attributes[attr_name].type.changed?(original_value, value, value)
          end.compact
        end

        def _touch_row(attribute_names, time)
          @_touch_attr_names = Set.new(attribute_names)

          affected_rows = super

          if @_skip_dirty_tracking ||= false
            clear_attribute_changes(@_touch_attr_names)
            return affected_rows
          end

          changes = {}
          @attributes.keys.each do |attr_name|
            next if @_touch_attr_names.include?(attr_name)

            if attribute_changed?(attr_name)
              changes[attr_name] = _read_attribute(attr_name)
              _write_attribute(attr_name, attribute_was(attr_name))
              clear_attribute_change(attr_name)
            end
          end

          changes_applied
          remember_transaction_changes
          changes.each { |attr_name, value| _write_attribute(attr_name, value) }

          affected_rows
        ensure
          @_touch_attr_names, @_skip_dirty_tracking = nil, nil
        end

        def _update_record(attribute_names = attribute_names_for_partial_updates)
          affected_rows = super
          changes_applied
          remember_transaction_changes
          affected_rows
        end

        def _create_record(attribute_names = attribute_names_for_partial_inserts)
          id = super
          changes_applied
          remember_transaction_changes
          id
        end

        def attribute_names_for_partial_updates
          partial_updates? ? changed_attribute_names_to_save : attribute_names
        end

        def attribute_names_for_partial_inserts
          if partial_inserts?
            changed_attribute_names_to_save
          else
            attribute_names.reject do |attr_name|
              if column_for_attribute(attr_name).auto_populated_on_insert? ||
                  self.class.counter_cache_column?(attr_name)
                !attribute_changed?(attr_name)
              end
            end
          end
        end
    end
  end
end
