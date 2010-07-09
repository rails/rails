require 'active_model/attribute_methods'
require 'active_support/concern'
require 'active_support/hash_with_indifferent_access'
require 'active_support/core_ext/object/duplicable'

module ActiveModel
  # == Active Model Dirty
  #
  # Provides a way to track changes in your object in the same way as 
  # Active Record does.
  # 
  # The requirements to implement ActiveModel::Dirty are to:
  #
  # * <tt>include ActiveModel::Dirty</tt> in your object
  # * Call <tt>define_attribute_methods</tt> passing each method you want to 
  #   track
  # * Call <tt>attr_name_will_change!</tt> before each change to the tracked 
  #   attribute
  # 
  # If you wish to also track previous changes on save or update, you need to 
  # add
  # 
  #   @previously_changed = changes
  # 
  # inside of your save or update method.
  # 
  # A minimal implementation could be:
  # 
  #   class Person
  #   
  #     include ActiveModel::Dirty
  #   
  #     define_attribute_methods [:name]
  #   
  #     def name
  #       @name
  #     end
  #   
  #     def name=(val)
  #       name_will_change!
  #       @name = val
  #     end
  #   
  #     def save
  #       @previously_changed = changes
  #     end
  #   
  #   end
  # 
  # == Examples:
  #
  # A newly instantiated object is unchanged:
  #   person = Person.find_by_name('Uncle Bob')
  #   person.changed?       # => false
  #
  # Change the name:
  #   person.name = 'Bob'
  #   person.changed?       # => true
  #   person.name_changed?  # => true
  #   person.name_was       # => 'Uncle Bob'
  #   person.name_change    # => ['Uncle Bob', 'Bob']
  #   person.name = 'Bill'
  #   person.name_change    # => ['Uncle Bob', 'Bill']
  #
  # Save the changes:
  #   person.save
  #   person.changed?       # => false
  #   person.name_changed?  # => false
  #
  # Assigning the same value leaves the attribute unchanged:
  #   person.name = 'Bill'
  #   person.name_changed?  # => false
  #   person.name_change    # => nil
  #
  # Which attributes have changed?
  #   person.name = 'Bob'
  #   person.changed        # => ['name']
  #   person.changes        # => { 'name' => ['Bill', 'Bob'] }
  #
  # Resetting an attribute returns it to its original state:
  #   person.reset_name!    # => 'Bill'
  #   person.changed?       # => false
  #   person.name_changed?  # => false
  #   person.name           # => 'Bill'
  #
  # Before modifying an attribute in-place:
  #   person.name_will_change!
  #   person.name << 'y'
  #   person.name_change    # => ['Bill', 'Billy']
  module Dirty
    extend ActiveSupport::Concern
    include ActiveModel::AttributeMethods

    included do
      attribute_method_suffix '_changed?', '_change', '_will_change!', '_was'
      attribute_method_affix :prefix => 'reset_', :suffix => '!'
    end

    # Do any attributes have unsaved changes?
    #   person.changed? # => false
    #   person.name = 'bob'
    #   person.changed? # => true
    def changed?
      !changed_attributes.empty?
    end

    # List of attributes with unsaved changes.
    #   person.changed # => []
    #   person.name = 'bob'
    #   person.changed # => ['name']
    def changed
      changed_attributes.keys
    end

    # Map of changed attrs => [original value, new value].
    #   person.changes # => {}
    #   person.name = 'bob'
    #   person.changes # => { 'name' => ['bill', 'bob'] }
    def changes
      changed.inject(HashWithIndifferentAccess.new){ |h, attr| h[attr] = attribute_change(attr); h }
    end

    # Map of attributes that were changed when the model was saved.
    #   person.name # => 'bob'
    #   person.name = 'robert'
    #   person.save
    #   person.previous_changes # => {'name' => ['bob, 'robert']}
    def previous_changes
      @previously_changed
    end

    # Map of change <tt>attr => original value</tt>.
    def changed_attributes
      @changed_attributes ||= {}
    end

    private

      # Handle <tt>*_changed?</tt> for +method_missing+.
      def attribute_changed?(attr)
        changed_attributes.include?(attr)
      end

      # Handle <tt>*_change</tt> for +method_missing+.
      def attribute_change(attr)
        [changed_attributes[attr], __send__(attr)] if attribute_changed?(attr)
      end

      # Handle <tt>*_was</tt> for +method_missing+.
      def attribute_was(attr)
        attribute_changed?(attr) ? changed_attributes[attr] : __send__(attr)
      end

      # Handle <tt>*_will_change!</tt> for +method_missing+.
      def attribute_will_change!(attr)
        begin
          value = __send__(attr)
          value = value.duplicable? ? value.clone : value
        rescue TypeError, NoMethodError
        end

        changed_attributes[attr] = value
      end

      # Handle <tt>reset_*!</tt> for +method_missing+.
      def reset_attribute!(attr)
        __send__("#{attr}=", changed_attributes[attr]) if attribute_changed?(attr)
      end
  end
end
