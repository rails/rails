module ActiveModel
  # == Active \Model \Identity
  #
  # Makes objects of the same type be considered equal if they have the same ID.
  #
  # To implement, just include ActiveModel::Identity in your class:
  #
  #   class User
  #     include ActiveModel::Identity
  #
  #     attr_accessor :id
  #     key_attributes :id
  #   end
  #
  # Two objects without IDs are not equal:
  #
  #   user1 = User.new
  #   user2 = User.new
  #   user2 == user1 # => false
  #
  # Two objects with different IDs are not equal:
  #
  #   user1.id = 1
  #   user2.id = 2
  #   user2 == user1 # => false
  #
  # Two objects of different types are not equal:
  #
  #   product = Product.new
  #   product.id = 1
  #   product == user1 # => false
  #
  # Two objects with the same type and ID are considered equal:
  #
  #   user2.id = 1
  #   user2 == user1 # => true
  #
  # The only requirement is that your object responds to +id+.
  module Identity
    extend ActiveSupport::Concern

    included do
      class_attribute :key_attribute_names
      # Defaults to no attributes.
      self.key_attribute_names = []
    end

    # Returns an Array of all key attributes if any is set, regardless if
    # the object is persisted or not. Returns +nil+ if there are no key attributes.
    #
    #   class Person
    #     include ActiveModel::Identity
    #     attr_accessor :id
    #   end
    #
    #   person = Person.create(id: 1)
    #   person.to_key # => [1]
    def to_key
      keys = self.class.key_attributes.map do |attribute|
        if respond_to?(attribute)
          send(attribute)
        else
          nil
        end
      end
      keys.any? ? keys : nil
    end

    # Returns true if +comparison_object+ is the same exact object, or +comparison_object+
    # is of the same type and +self+ has an ID and it is equal to +comparison_object.id+.
    #
    # Note that new records are different from any other record by definition, unless the
    # other record is the receiver itself. Besides, if you fetch existing records with
    # +select+ and leave the ID out, you're on your own, this predicate will return false.
    #
    # Note also that destroying a record preserves its ID in the model instance, so deleted
    # models are still comparable.
    def ==(comparison_object)
      super ||
        comparison_object.instance_of?(self.class) &&
        !(key = to_key).nil? &&
        comparison_object.to_key == key
    end
    alias :eql? :==

    # Delegates to id in order to allow two records of the same type and id to work with something like:
    #   [ Person.find(1), Person.find(2), Person.find(3) ] & [ Person.find(1), Person.find(4) ] # => [ Person.find(1) ]
    def hash
      key = to_key
      if key
        key.hash
      else
        super
      end
    end

    module ClassMethods
      # Sets or returns the symbols of attribute names which should be used for
      # identity checking. For example, if your models are unique by first and
      # last name, this could be set to use +:first+ and +:last+:
      #
      #   class Person
      #     include ActiveModel::Identity
      #     key_attributes :first, :last
      #   end
      #
      #   Person.key_attributes # => [:first, :last]
      #   person = Person.create(first: 'John', last: 'Smith')
      #   person.to_key # => ['John', 'Smith']
      def key_attributes(*attrs)
        if attrs.empty?
          self.key_attribute_names
        else
          self.key_attribute_names = attrs
        end
      end
    end
  end
end
