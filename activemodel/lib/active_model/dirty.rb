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

    # Returns a hash of changed attributes indicating their original
    # and new values like <tt>attr => [original value, new value]</tt>.
    #
    #   person.changes # => {}
    #   person.name = 'bob'
    #   person.changes # => { "name" => ["bill", "bob"] }
    def changes
      ActiveSupport::HashWithIndifferentAccess[changed.map { |attr| [attr, attribute_change(attr)] }]
    end

    # Returns a hash of attributes that were changed before the model was saved.
    #
    #   person.name # => "bob"
    #   person.name = 'robert'
    #   person.save
    #   person.previous_changes # => {"name" => ["bob", "robert"]}
    def previous_changes
      @previously_changed ||= ActiveSupport::HashWithIndifferentAccess.new
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
      result = changed_attributes.include?(attr)
      result &&= options[:to] == __send__(attr) if options.key?(:to)
      result &&= options[:from] == changed_attributes[attr] if options.key?(:from)
      result
    end

    # Handle <tt>*_was</tt> for +method_missing+.
    def attribute_was(attr) # :nodoc:
      attribute_changed?(attr) ? changed_attributes[attr] : __send__(attr)
    end

    private

      # Removes current changes and makes them accessible through +previous_changes+.
      def changes_applied
        @previously_changed = changes
        @changed_attributes = ActiveSupport::HashWithIndifferentAccess.new
      end

      # Removes all dirty data: current changes and previous changes
      def reset_changes
        @previously_changed = ActiveSupport::HashWithIndifferentAccess.new
        @changed_attributes = ActiveSupport::HashWithIndifferentAccess.new
      end

      # Handle <tt>*_change</tt> for +method_missing+.
      def attribute_change(attr)
        [changed_attributes[attr], __send__(attr)] if attribute_changed?(attr)
      end

      # Handle <tt>*_will_change!</tt> for +method_missing+.
      def attribute_will_change!(attr)
        return if attribute_changed?(attr)

        begin
          value = __send__(attr)
          value = value.duplicable? ? value.clone : value
        rescue TypeError, NoMethodError
        end

        changed_attributes[attr] = value
      end

      # Handle <tt>reset_*!</tt> for +method_missing+.
      def reset_attribute!(attr)
        if attribute_changed?(attr)
          __send__("#{attr}=", changed_attributes[attr])
          changed_attributes.delete(attr)
        end
      end
  end
end
