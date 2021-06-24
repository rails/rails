# frozen_string_literal: true

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
  #   person.name_previously_changed?(from: nil, to: "Bill") # => true
  #   person.name_previous_change     # => [nil, "Bill"]
  #   person.name_previously_was      # => nil
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

    included do
      attribute_method_suffix "_changed?", "_change", "_will_change!", "_was"
      attribute_method_suffix "_previously_changed?", "_previous_change", "_previously_was"
      attribute_method_affix prefix: "restore_", suffix: "!"
      attribute_method_affix prefix: "clear_", suffix: "_change"
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

    def as_json(options = {}) # :nodoc:
      options[:except] = [options[:except], "mutations_from_database"].flatten
      super(options)
    end

    # Clears dirty data and moves +changes+ to +previous_changes+ and
    # +mutations_from_database+ to +mutations_before_last_save+ respectively.
    def changes_applied
      unless defined?(@attributes)
        mutations_from_database.finalize_changes
      end
      @mutations_before_last_save = mutations_from_database
      forget_attribute_assignments
      @mutations_from_database = nil
    end

    # Returns +true+ if any of the attributes has unsaved changes, +false+ otherwise.
    #
    #   person.changed? # => false
    #   person.name = 'bob'
    #   person.changed? # => true
    def changed?
      mutations_from_database.any_changes?
    end

    # Returns an array with the name of the attributes with unsaved changes.
    #
    #   person.changed # => []
    #   person.name = 'bob'
    #   person.changed # => ["name"]
    def changed
      mutations_from_database.changed_attribute_names
    end

    # Dispatch target for <tt>*_changed?</tt> attribute methods.
    def attribute_changed?(attr_name, **options) # :nodoc:
      mutations_from_database.changed?(attr_name.to_s, **options)
    end

    # Dispatch target for <tt>*_was</tt> attribute methods.
    def attribute_was(attr_name) # :nodoc:
      mutations_from_database.original_value(attr_name.to_s)
    end

    # Dispatch target for <tt>*_previously_changed?</tt> attribute methods.
    def attribute_previously_changed?(attr_name, **options) # :nodoc:
      mutations_before_last_save.changed?(attr_name.to_s, **options)
    end

    # Dispatch target for <tt>*_previously_was</tt> attribute methods.
    def attribute_previously_was(attr_name) # :nodoc:
      mutations_before_last_save.original_value(attr_name.to_s)
    end

    # Restore all previous data of the provided attributes.
    def restore_attributes(attr_names = changed)
      attr_names.each { |attr_name| restore_attribute!(attr_name) }
    end

    # Clears all dirty data: current changes and previous changes.
    def clear_changes_information
      @mutations_before_last_save = nil
      forget_attribute_assignments
      @mutations_from_database = nil
    end

    def clear_attribute_changes(attr_names)
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
      mutations_from_database.changed_values
    end

    # Returns a hash of changed attributes indicating their original
    # and new values like <tt>attr => [original value, new value]</tt>.
    #
    #   person.changes # => {}
    #   person.name = 'bob'
    #   person.changes # => { "name" => ["bill", "bob"] }
    def changes
      mutations_from_database.changes
    end

    # Returns a hash of attributes that were changed before the model was saved.
    #
    #   person.name # => "bob"
    #   person.name = 'robert'
    #   person.save
    #   person.previous_changes # => {"name" => ["bob", "robert"]}
    def previous_changes
      mutations_before_last_save.changes
    end

    def attribute_changed_in_place?(attr_name) # :nodoc:
      mutations_from_database.changed_in_place?(attr_name.to_s)
    end

    private
      def clear_attribute_change(attr_name)
        mutations_from_database.forget_change(attr_name.to_s)
      end

      def mutations_from_database
        @mutations_from_database ||= if defined?(@attributes)
          ActiveModel::AttributeMutationTracker.new(@attributes)
        else
          ActiveModel::ForcedMutationTracker.new(self)
        end
      end

      def forget_attribute_assignments
        @attributes = @attributes.map(&:forgetting_assignment) if defined?(@attributes)
      end

      def mutations_before_last_save
        @mutations_before_last_save ||= ActiveModel::NullMutationTracker.instance
      end

      # Dispatch target for <tt>*_change</tt> attribute methods.
      def attribute_change(attr_name)
        mutations_from_database.change_to_attribute(attr_name.to_s)
      end

      # Dispatch target for <tt>*_previous_change</tt> attribute methods.
      def attribute_previous_change(attr_name)
        mutations_before_last_save.change_to_attribute(attr_name.to_s)
      end

      # Dispatch target for <tt>*_will_change!</tt> attribute methods.
      def attribute_will_change!(attr_name)
        mutations_from_database.force_change(attr_name.to_s)
      end

      # Dispatch target for <tt>restore_*!</tt> attribute methods.
      def restore_attribute!(attr_name)
        attr_name = attr_name.to_s
        if attribute_changed?(attr_name)
          __send__("#{attr_name}=", attribute_was(attr_name))
          clear_attribute_change(attr_name)
        end
      end
  end
end
