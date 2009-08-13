module ActiveModel
  # Track unsaved attribute changes.
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
      changed.inject({}) { |h, attr| h[attr] = attribute_change(attr); h }
    end

    private
      # Map of change <tt>attr => original value</tt>.
      def changed_attributes
        @changed_attributes ||= {}
      end

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
