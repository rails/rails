require 'active_support/hash_with_indifferent_access'
require 'active_support/core_ext/object/duplicable'

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
  # * Call <tt>attr_name_will_change!</tt> before each change to the tracked
  #   attribute.
  # * Call <tt>changes_applied</tt> after the changes are persisted.
  # * Call <tt>reset_changes</tt> when you want to reset the changes
  #   information.
  #
  # A minimal implementation could be:
  #
  #   class Person
  #     include ActiveModel::Dirty
  #
  #     define_attribute_methods :name
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
  #       changes_applied
  #     end
  #
  #     def reload!
  #       reset_changes
  #     end
  #   end
  #
  # A newly instantiated object is unchanged:
  #
  #   person = Person.find_by(name: 'Uncle Bob')
  #   person.changed?       # => false
  #
  # Change the name:
  #
  #   person.name = 'Bob'
  #   person.changed?       # => true
  #   person.name_changed?  # => true
  #   person.name_changed?(from: "Uncle Bob", to: "Bob") # => true
  #   person.name_was       # => "Uncle Bob"
  #   person.name_change    # => ["Uncle Bob", "Bob"]
  #   person.name = 'Bill'
  #   person.name_change    # => ["Uncle Bob", "Bill"]
  #
  # Save the changes:
  #
  #   person.save
  #   person.changed?       # => false
  #   person.name_changed?  # => false
  #
  # Reset the changes:
  #
  #   person.previous_changes # => {"name" => ["Uncle Bob", "Bill"]}
  #   person.reload!
  #   person.previous_changes # => {}
  #
  # Assigning the same value leaves the attribute unchanged:
  #
  #   person.name = 'Bill'
  #   person.name_changed?  # => false
  #   person.name_change    # => nil
  #
  # Which attributes have changed?
  #
  #   person.name = 'Bob'
  #   person.changed        # => ["name"]
  #   person.changes        # => {"name" => ["Bill", "Bob"]}
  #
  # If an attribute is modified in-place then make use of <tt>[attribute_name]_will_change!</tt>
  # to mark that the attribute is changing. Otherwise ActiveModel can't track
  # changes to in-place attributes.
  #
  #   person.name_will_change!
  #   person.name_change    # => ["Bill", "Bill"]
  #   person.name << 'y'
  #   person.name_change    # => ["Bill", "Billy"]
  module Dirty
    extend ActiveSupport::Concern
    include ActiveModel::AttributeMethods

    included do
      attribute_method_suffix '_changed?', '_change', '_will_change!', '_was'
      attribute_method_affix prefix: 'reset_', suffix: '!'
    end

    # Returns +true+ if any attribute have unsaved changes, +false+ otherwise.
    #
    #   person.changed? # => false
    #   person.name = 'bob'
    #   person.changed? # => true
    def changed?
      changes.present?
    end

    # Returns an array with the name of the attributes with unsaved changes.
    #
    #   person.changed # => []
    #   person.name = 'bob'
    #   person.changed # => ["name"]
    def changed
      changes.keys
    end

    # Returns a hash of changed attributes indicating their original
    # and new values like <tt>attr => [original value, new value]</tt>.
    #
    #   person.changes # => {}
    #   person.name = 'bob'
    #   person.changes # => { "name" => ["bill", "bob"] }
    def changes
      original_values.keys.each_with_object(ActiveSupport::HashWithIndifferentAccess.new) do |attr, hash|
        change = attribute_change(attr)
        hash[attr] = change if change
      end
    end

    # Returns a hash of attributes that were changed before the model was saved.
    #
    #   person.name # => "bob"
    #   person.name = 'robert'
    #   person.save
    #   person.previous_changes # => {"name" => ["bob", "robert"]}
    def previous_changes
      @previously_changed ||= {}
    end

    def original_values
      @original_values ||= {}
    end

    # Returns a hash of the attributes with unsaved changes indicating their original
    # values like <tt>attr => original value</tt>.
    #
    #   person.name # => "bob"
    #   person.name = 'robert'
    #   person.changed_attributes # => {"name" => "bob"}
    def changed_attributes
      @changed_attributes ||= ActiveSupport::HashWithIndifferentAccess.new
    end

    # Handle <tt>*_changed?</tt> for +method_missing+.
    def attribute_changed?(attr, options = {}) #:nodoc:
      value_pairs = attribute_change(attr)
      result = ! value_pairs.nil?
      result &&= options[:to].hash == value_pairs.last.hash if options.key?(:to)
      result &&= options[:from].hash == value_pairs.first.hash if options.key?(:from)
      result
    end

    # Handle <tt>*_was</tt> for +method_missing+.
    def attribute_was(attr) # :nodoc:
      attr = attr.to_s
      original_values.key?(attr) ? original_values[attr] : __send__(attr)
    end

    # mark a column as not changed (but don't change the value)
    def reset_change(attr)
      changed_attributes.delete(attr)
      original_values.delete(attr)
    end

    private

      def _field_changed?(attr, old, value)
        old != value
      end

      # Removes current changes and makes them accessible through +previous_changes+.
      def changes_applied
        @previously_changed = changes
        @changed_attributes = {}
        @original_values = nil
      end

      # Removes all dirty data: current changes and previous changes
      def reset_changes
        @previously_changed = {}
        @changed_attributes = {}
        @original_values = nil
      end

      # Handle <tt>*_change</tt> for +method_missing+.
      def attribute_change(attr)
        attr = attr.to_s
        if original_values.key?(attr)
          old = original_values[attr]
          value = __send__(attr)
          [old, value] if changed_attributes.key?(attr)
        end
      end

      # Handle <tt>*_will_change!</tt> for +method_missing+.
      def attribute_will_change!(attr)
        set_original_value(attr)
      end

      def set_original_value(*args)
        attr = args.first
        begin
          value = args.length < 2 ? __send__(attr) : args[1]
          value = value.duplicable? ? value.clone : value
        rescue TypeError, NoMethodError
        end

        if ! original_values.key?(attr)
          original_values[attr] = value
        end
        if ! changed_attributes.key?(attr) && (args.length < 3 || value != args[2])
          changed_attributes[attr] = value
        end
      end

      # Handle <tt>reset_*!</tt> for +method_missing+.
      def reset_attribute!(attr)
        attr = attr.to_s
        if original_values.key?(attr)
          __send__("#{attr}=", original_values[attr])
          reset_change(attr)
        end
      end
  end
end
