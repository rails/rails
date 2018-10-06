# frozen_string_literal: true

require "active_support/hash_with_indifferent_access"
require "active_support/core_ext/object/duplicable"
require "active_model/attribute_mutation_tracker"

module ActiveModel
  # == Active \Model \Dirty
  #
  # Provides a way to track changes in your object in the same way as
  # Active Record does.
  #
  # The requirements for implementing ActiveModel::Dirty are:
  #
  # * <tt>include ActiveModel::Dirty</tt> in your object.
  # * Call <tt>define_attribute_methods</tt> passing each method you want to
  #   track.
  # * Call <tt>[attr_name]_will_change!</tt> before each change to the tracked
  #   attribute.
  # * Call <tt>changes_applied</tt> after the changes are persisted.
  # * Call <tt>clear_changes_information</tt> when you want to reset the changes
  #   information.
  # * Call <tt>restore_attributes</tt> when you want to restore previous data.
  #
  # A minimal implementation could be:
  #
  #   class Person
  #     include ActiveModel::Dirty
  #
  #     define_attribute_methods :name
  #
  #     def initialize
  #       @name = nil
  #     end
  #
  #     def name
  #       @name
  #     end
  #
  #     def name=(val)
  #       name_will_change! unless val == @name
  #       @name = val
  #     end
  #
  #     def save
  #       # do persistence work
  #
  #       changes_applied
  #     end
  #
  #     def reload!
  #       # get the values from the persistence layer
  #
  #       clear_changes_information
  #     end
  #
  #     def rollback!
  #       restore_attributes
  #     end
  #   end
  #
  # A newly instantiated +Person+ object is unchanged:
  #
  #   person = Person.new
  #   person.changed? # => false
  #
  # Change the name:
  #
  #   person.name = 'Bob'
  #   person.changed?       # => true
  #   person.name_changed?  # => true
  #   person.name_changed?(from: nil, to: "Bob") # => true
  #   person.name_was       # => nil
  #   person.name_change    # => [nil, "Bob"]
  #   person.name = 'Bill'
  #   person.name_change    # => [nil, "Bill"]
  #
  # Save the changes:
  #
  #   person.save
  #   person.changed?      # => false
  #   person.name_changed? # => false
  #
  # Reset the changes:
  #
  #   person.previous_changes         # => {"name" => [nil, "Bill"]}
  #   person.name_previously_changed? # => true
  #   person.name_previous_change     # => [nil, "Bill"]
  #   person.reload!
  #   person.previous_changes         # => {}
  #
  # Rollback the changes:
  #
  #   person.name = "Uncle Bob"
  #   person.rollback!
  #   person.name          # => "Bill"
  #   person.name_changed? # => false
  #
  # Assigning the same value leaves the attribute unchanged:
  #
  #   person.name = 'Bill'
  #   person.name_changed? # => false
  #   person.name_change   # => nil
  #
  # Which attributes have changed?
  #
  #   person.name = 'Bob'
  #   person.changed # => ["name"]
  #   person.changes # => {"name" => ["Bill", "Bob"]}
  #
  # If an attribute is modified in-place then make use of
  # <tt>[attribute_name]_will_change!</tt> to mark that the attribute is changing.
  # Otherwise \Active \Model can't track changes to in-place attributes. Note
  # that Active Record can detect in-place modifications automatically. You do
  # not need to call <tt>[attribute_name]_will_change!</tt> on Active Record models.
  #
  #   person.name_will_change!
  #   person.name_change # => ["Bill", "Bill"]
  #   person.name << 'y'
  #   person.name_change # => ["Bill", "Billy"]
  module Dirty
    extend ActiveSupport::Concern
    include ActiveModel::AttributeMethods

    OPTION_NOT_GIVEN = Object.new # :nodoc:
    private_constant :OPTION_NOT_GIVEN

    included do
      attribute_method_suffix "_changed?", "_change", "_will_change!", "_was"
      attribute_method_suffix "_previously_changed?", "_previous_change"
      attribute_method_affix prefix: "restore_", suffix: "!"
    end

    def initialize_dup(other) # :nodoc:
      super
      if self.class.respond_to?(:_default_attributes)
        @attributes = self.class._default_attributes.map do |attr|
          attr.with_value_from_user(@attributes.fetch_value(attr.name))
        end
      end
      @mutations_from_database = nil
    end

    def changes_applied # :nodoc:
      unless defined?(@attributes)
        @previously_changed = changes
      end
      @mutations_before_last_save = mutations_from_database
      @attributes_changed_by_setter = ActiveSupport::HashWithIndifferentAccess.new
      forget_attribute_assignments
      @mutations_from_database = nil
    end

    # Returns +true+ if any of the attributes have unsaved changes, +false+ otherwise.
    #
    #   person.changed? # => false
    #   person.name = 'bob'
    #   person.changed? # => true
    def changed?
      changed_attributes.present?
    end

    # Returns an array with the name of the attributes with unsaved changes.
    #
    #   person.changed # => []
    #   person.name = 'bob'
    #   person.changed # => ["name"]
    def changed
      changed_attributes.keys
    end

    # Handles <tt>*_changed?</tt> for +method_missing+.
    def attribute_changed?(attr, from: OPTION_NOT_GIVEN, to: OPTION_NOT_GIVEN) # :nodoc:
      !!changes_include?(attr) &&
        (to == OPTION_NOT_GIVEN || to == _read_attribute(attr)) &&
        (from == OPTION_NOT_GIVEN || from == changed_attributes[attr])
    end

    # Handles <tt>*_was</tt> for +method_missing+.
    def attribute_was(attr) # :nodoc:
      attribute_changed?(attr) ? changed_attributes[attr] : _read_attribute(attr)
    end

    # Handles <tt>*_previously_changed?</tt> for +method_missing+.
    def attribute_previously_changed?(attr) #:nodoc:
      previous_changes_include?(attr)
    end

    # Restore all previous data of the provided attributes.
    def restore_attributes(attributes = changed)
      attributes.each { |attr| restore_attribute! attr }
    end

    # Clears all dirty data: current changes and previous changes.
    def clear_changes_information
      @previously_changed = ActiveSupport::HashWithIndifferentAccess.new
      @mutations_before_last_save = nil
      @attributes_changed_by_setter = ActiveSupport::HashWithIndifferentAccess.new
      forget_attribute_assignments
      @mutations_from_database = nil
    end

    def clear_attribute_changes(attr_names)
      attributes_changed_by_setter.except!(*attr_names)
      attr_names.each do |attr_name|
        clear_attribute_change(attr_name)
      end
    end

    # Returns a hash of the attributes with unsaved changes indicating their original
    # values like <tt>attr => original value</tt>.
    #
    #   person.name # => "bob"
    #   person.name = 'robert'
    #   person.changed_attributes # => {"name" => "bob"}
    def changed_attributes
      # This should only be set by methods which will call changed_attributes
      # multiple times when it is known that the computed value cannot change.
      if defined?(@cached_changed_attributes)
        @cached_changed_attributes
      else
        attributes_changed_by_setter.reverse_merge(mutations_from_database.changed_values).freeze
      end
    end

    # Returns a hash of changed attributes indicating their original
    # and new values like <tt>attr => [original value, new value]</tt>.
    #
    #   person.changes # => {}
    #   person.name = 'bob'
    #   person.changes # => { "name" => ["bill", "bob"] }
    def changes
      cache_changed_attributes do
        ActiveSupport::HashWithIndifferentAccess[changed.map { |attr| [attr, attribute_change(attr)] }]
      end
    end

    # Returns a hash of attributes that were changed before the model was saved.
    #
    #   person.name # => "bob"
    #   person.name = 'robert'
    #   person.save
    #   person.previous_changes # => {"name" => ["bob", "robert"]}
    def previous_changes
      @previously_changed ||= ActiveSupport::HashWithIndifferentAccess.new
      @previously_changed.merge(mutations_before_last_save.changes)
    end

    def attribute_changed_in_place?(attr_name) # :nodoc:
      mutations_from_database.changed_in_place?(attr_name)
    end

    private
      def clear_attribute_change(attr_name)
        mutations_from_database.forget_change(attr_name)
      end

      def mutations_from_database
        unless defined?(@mutations_from_database)
          @mutations_from_database = nil
        end
        @mutations_from_database ||= if defined?(@attributes)
          ActiveModel::AttributeMutationTracker.new(@attributes)
        else
          NullMutationTracker.instance
        end
      end

      def forget_attribute_assignments
        @attributes = @attributes.map(&:forgetting_assignment) if defined?(@attributes)
      end

      def mutations_before_last_save
        @mutations_before_last_save ||= ActiveModel::NullMutationTracker.instance
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

      # Returns +true+ if attr_name is changed, +false+ otherwise.
      def changes_include?(attr_name)
        attributes_changed_by_setter.include?(attr_name) || mutations_from_database.changed?(attr_name)
      end
      alias attribute_changed_by_setter? changes_include?

      # Returns +true+ if attr_name were changed before the model was saved,
      # +false+ otherwise.
      def previous_changes_include?(attr_name)
        previous_changes.include?(attr_name)
      end

      # Handles <tt>*_change</tt> for +method_missing+.
      def attribute_change(attr)
        [changed_attributes[attr], _read_attribute(attr)] if attribute_changed?(attr)
      end

      # Handles <tt>*_previous_change</tt> for +method_missing+.
      def attribute_previous_change(attr)
        previous_changes[attr]
      end

      # Handles <tt>*_will_change!</tt> for +method_missing+.
      def attribute_will_change!(attr)
        unless attribute_changed?(attr)
          begin
            value = _read_attribute(attr)
            value = value.duplicable? ? value.clone : value
          rescue TypeError, NoMethodError
          end

          set_attribute_was(attr, value)
        end
        mutations_from_database.force_change(attr)
      end

      # Handles <tt>restore_*!</tt> for +method_missing+.
      def restore_attribute!(attr)
        if attribute_changed?(attr)
          __send__("#{attr}=", changed_attributes[attr])
          clear_attribute_changes([attr])
        end
      end

      def attributes_changed_by_setter
        @attributes_changed_by_setter ||= ActiveSupport::HashWithIndifferentAccess.new
      end

      # Force an attribute to have a particular "before" value
      def set_attribute_was(attr, old_value)
        attributes_changed_by_setter[attr] = old_value
      end
  end
end
