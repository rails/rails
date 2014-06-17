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
        !id.nil? &&
        comparison_object.id == id
    end
    alias :eql? :==

    # Delegates to id in order to allow two records of the same type and id to work with something like:
    #   [ Person.find(1), Person.find(2), Person.find(3) ] & [ Person.find(1), Person.find(4) ] # => [ Person.find(1) ]
    def hash
      if id
        id.hash
      else
        super
      end
    end
  end
end
