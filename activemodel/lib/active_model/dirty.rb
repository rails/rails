require "active_support/hash_with_indifferent_access"
require "active_support/core_ext/object/duplicable"

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

    # Handles <tt>*_changed?</tt> for +method_missing+.
    def attribute_changed?(attr, from: OPTION_NOT_GIVEN, to: OPTION_NOT_GIVEN) # :nodoc:
      !!changes_include?(attr) &&
        (to == OPTION_NOT_GIVEN || to == __send__(attr)) &&
        (from == OPTION_NOT_GIVEN || from == changed_attributes[attr])
    end

    # Handles <tt>*_was</tt> for +method_missing+.
    def attribute_was(attr) # :nodoc:
      attribute_changed?(attr) ? changed_attributes[attr] : __send__(attr)
    end

    # Handles <tt>*_previously_changed?</tt> for +method_missing+.
    def attribute_previously_changed?(attr) #:nodoc:
      previous_changes_include?(attr)
    end

    # Restore all previous data of the provided attributes.
    def restore_attributes(attributes = changed)
      attributes.each { |attr| restore_attribute! attr }
    end

    private

      # Returns +true+ if attr_name is changed, +false+ otherwise.
      def changes_include?(attr_name)
        attributes_changed_by_setter.include?(attr_name)
      end
      alias attribute_changed_by_setter? changes_include?

      # Returns +true+ if attr_name were changed before the model was saved,
      # +false+ otherwise.
      def previous_changes_include?(attr_name)
        previous_changes.include?(attr_name)
      end

      # Removes current changes and makes them accessible through +previous_changes+.
      def changes_applied # :doc:
        @previously_changed = changes
        @changed_attributes = ActiveSupport::HashWithIndifferentAccess.new
      end

      # Clears all dirty data: current changes and previous changes.
      def clear_changes_information # :doc:
        @previously_changed = ActiveSupport::HashWithIndifferentAccess.new
        @changed_attributes = ActiveSupport::HashWithIndifferentAccess.new
      end

      # Handles <tt>*_change</tt> for +method_missing+.
      def attribute_change(attr)
        [changed_attributes[attr], __send__(attr)] if attribute_changed?(attr)
      end

      # Handles <tt>*_previous_change</tt> for +method_missing+.
      def attribute_previous_change(attr)
        previous_changes[attr] if attribute_previously_changed?(attr)
      end

      # Handles <tt>*_will_change!</tt> for +method_missing+.
      def attribute_will_change!(attr)
        return if attribute_changed?(attr)

        begin
          value = __send__(attr)
          value = value.duplicable? ? value.clone : value
        rescue TypeError, NoMethodError
        end

        set_attribute_was(attr, value)
      end

      # Handles <tt>restore_*!</tt> for +method_missing+.
      def restore_attribute!(attr)
        if attribute_changed?(attr)
          __send__("#{attr}=", changed_attributes[attr])
          clear_attribute_changes([attr])
        end
      end

      # This is necessary because `changed_attributes` might be overridden in
      # other implementations (e.g. in `ActiveRecord`)
      alias_method :attributes_changed_by_setter, :changed_attributes # :nodoc:

      # Force an attribute to have a particular "before" value
      def set_attribute_was(attr, old_value)
        attributes_changed_by_setter[attr] = old_value
      end

      # Remove changes information for the provided attributes.
      def clear_attribute_changes(attributes) # :doc:
        attributes_changed_by_setter.except!(*attributes)
      end
  end
end
