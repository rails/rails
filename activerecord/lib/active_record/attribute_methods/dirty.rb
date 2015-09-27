require 'active_support/core_ext/module/attribute_accessors'
require 'active_record/attribute_mutation_tracker'

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
          clear_changes_information
        end
      end

      def init_internals
        super
        @mutation_tracker = AttributeMutationTracker.new(@attributes, @attributes.dup)
      end

      def initialize_dup(other) # :nodoc:
        super
        @mutation_tracker = AttributeMutationTracker.new(@attributes,
                                                         self.class._default_attributes.dup)
      end

      def changes_applied
        @previous_mutation_tracker = @mutation_tracker
        @changed_attributes = HashWithIndifferentAccess.new
        store_original_attributes
      end

      def clear_changes_information
        @previous_mutation_tracker = nil
        @changed_attributes = HashWithIndifferentAccess.new
        store_original_attributes
      end

      def raw_write_attribute(attr_name, *)
        result = super
        clear_attribute_change(attr_name)
        result
      end

      def clear_attribute_changes(attr_names)
        super
        attr_names.each do |attr_name|
          clear_attribute_change(attr_name)
        end
      end

      def changed_attributes
        # This should only be set by methods which will call changed_attributes
        # multiple times when it is known that the computed value cannot change.
        if defined?(@cached_changed_attributes)
          @cached_changed_attributes
        else
          super.reverse_merge(@mutation_tracker.changed_values).freeze
        end
      end

      def changes
        cache_changed_attributes do
          super
        end
      end

      def previous_changes
        previous_mutation_tracker.changes
      end

      def attribute_changed_in_place?(attr_name)
        @mutation_tracker.changed_in_place?(attr_name)
      end

      private

      def changes_include?(attr_name)
        super || @mutation_tracker.changed?(attr_name)
      end

      def clear_attribute_change(attr_name)
        @mutation_tracker.forget_change(attr_name)
      end

      def _update_record(*)
        partial_writes? ? super(keys_for_partial_write) : super
      end

      def _create_record(*)
        partial_writes? ? super(keys_for_partial_write) : super
      end

      def keys_for_partial_write
        changed & self.class.column_names
      end

      def store_original_attributes
        @mutation_tracker = @mutation_tracker.now_tracking(@attributes)
      end

      def previous_mutation_tracker
        @previous_mutation_tracker ||= NullMutationTracker.new
      end

      def cache_changed_attributes
        @cached_changed_attributes = changed_attributes
        yield
      ensure
        clear_changed_attributes_cache
      end

      def clear_changed_attributes_cache
        remove_instance_variable(:@cached_changed_attributes) if defined?(@cached_changed_attributes)
      end
    end
  end
end
