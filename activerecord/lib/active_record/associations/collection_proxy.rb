module ActiveRecord
  module Associations
    # Association proxies in Active Record are middlemen between the object that
    # holds the association, known as the <tt>@owner</tt>, and the actual associated
    # object, known as the <tt>@target</tt>. The kind of association any proxy is
    # about is available in <tt>@reflection</tt>. That's an instance of the class
    # ActiveRecord::Reflection::AssociationReflection.
    #
    # For example, given
    #
    #   class Blog < ActiveRecord::Base
    #     has_many :posts
    #   end
    #
    #   blog = Blog.first
    #
    # the association proxy in <tt>blog.posts</tt> has the object in +blog+ as
    # <tt>@owner</tt>, the collection of its posts as <tt>@target</tt>, and
    # the <tt>@reflection</tt> object represents a <tt>:has_many</tt> macro.
    #
    # This class has most of the basic instance methods removed, and delegates
    # unknown methods to <tt>@target</tt> via <tt>method_missing</tt>. As a
    # corner case, it even removes the +class+ method and that's why you get
    #
    #   blog.posts.class # => Array
    #
    # though the object behind <tt>blog.posts</tt> is not an Array, but an
    # ActiveRecord::Associations::HasManyAssociation.
    #
    # The <tt>@target</tt> object is not \loaded until needed. For example,
    #
    #   blog.posts.count
    #
    # is computed directly through SQL and does not trigger by itself the
    # instantiation of the actual post records.
    class CollectionProxy < Relation
      delegate :target, :load_target, :loaded?, :to => :@association

      ##
      # :method: select
      #
      # Works in two ways.
      #
      # *First:* Specify a subset of fields to be selected from the result set.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets
      #   # => [
      #   #       #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>,
      #   #       #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #       #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]
      #
      #   person.pets.select(:name)
      #   # => [
      #   #      #<Pet id: nil, name: "Fancy-Fancy">,
      #   #      #<Pet id: nil, name: "Spook">,
      #   #      #<Pet id: nil, name: "Choo-Choo">
      #   #    ]
      #
      #   person.pets.select([:id, :name])
      #   # => [
      #   #      #<Pet id: 1, name: "Fancy-Fancy">,
      #   #      #<Pet id: 2, name: "Spook">,
      #   #      #<Pet id: 3, name: "Choo-Choo">
      #   #    ]
      #
      # Be careful because this also means you’re initializing a model
      # object with only the fields that you’ve selected. If you attempt
      # to access a field that is not in the initialized record you’ll
      # receive:
      #
      #   person.pets.select(:name).first.person_id
      #   # => ActiveModel::MissingAttributeError: missing attribute: person_id
      #
      # *Second:* You can pass a block so it can be used just like Array#select.
      # This build an array of objects from the database for the scope,
      # converting them into an array and iterating through them using
      # Array#select.
      #
      #   person.pets.select { |pet| pet.name =~ /oo/ }
      #   # => [
      #   #      #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #      #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]
      #
      #   person.pets.select(:name) { |pet| pet.name =~ /oo/ }

      ##
      # :method: find
      # Finds an object in the collection responding to the +id+. Uses the same
      # rules as +ActiveRecord::Base.find+. Returns +ActiveRecord::RecordNotFound++
      # error if the object can not be found.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets
      #   # => [
      #   #       #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>,
      #   #       #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #       #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]
      #   
      #   person.pets.find(1) # => #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>
      #   person.pets.find(4) # => ActiveRecord::RecordNotFound: Couldn't find Pet with id=4

      ##
      # :method: first
      # Returns the first record, or the first +n+ records, from the collection.
      # If the collection is empty, the first form returns nil, and the second
      # form returns an empty array.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets
      #   # => [
      #   #       #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>,
      #   #       #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #       #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]
      #
      #   person.pets.first # => #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>
      #
      #   person.pets.first(2)
      #   # => [
      #   #      #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>,
      #   #      #<Pet id: 2, name: "Spook", person_id: 1>
      #   #    ]
      #
      #   another_person_without.pets          # => []
      #   another_person_without.pets.first    # => nil
      #   another_person_without.pets.first(3) # => []

      ##
      # :method: last
      # Returns the last record, or the last +n+ records, from the collection.
      # If the collection is empty, the first form returns nil, and the second
      # form returns an empty array.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets
      #   # => [
      #   #       #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>,
      #   #       #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #       #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]
      #
      #   person.pets.last # => #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #
      #   person.pets.last(2)
      #   # => [
      #   #      #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #      #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]
      #
      #   another_person_without.pets         # => []
      #   another_person_without.pets.last    # => nil
      #   another_person_without.pets.last(3) # => []

      ##
      # :method: concat
      # Add one or more records to the collection by setting their foreign keys
      # to the association's primary key. Since << flattens its argument list and
      # inserts each record, +push+ and +concat+ behave identically. Returns +self+
      # so method calls may be chained.
      #
      #   class Person < ActiveRecord::Base
      #     pets :has_many
      #   end
      #
      #   person.pets.size # => 0
      #   person.pets.concat(Pet.new(name: 'Fancy-Fancy'))
      #   person.pets.concat(Pet.new(name: 'Spook'), Pet.new(name: 'Choo-Choo'))
      #   person.pets.size # => 3
      #
      #   person.id # => 1
      #   person.pets
      #   # => [
      #   #       #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>,
      #   #       #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #       #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]
      #
      #   person.pets.concat([Pet.new(name: 'Brain'), Pet.new(name: 'Benny')])
      #   person.pets.size # => 5

      ##
      # :method: replace
      # Replace this collection with +other_array+. This will perform a diff
      # and delete/add only records that have changed.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets
      #   # => [#<Pet id: 1, name: "Gorby", group: "cats", person_id: 1>]
      #
      #   other_pets = [Pet.new(name: 'Puff', group: 'celebrities']
      #
      #   person.pets.replace(other_pets)
      #
      #   person.pets
      #   # => [#<Pet id: 2, name: "Puff", group: "celebrities", person_id: 1>]
      #
      # If the supplied array has an incorrect association type, it raises
      # an <tt>ActiveRecord::AssociationTypeMismatch</tt> error:
      #
      #   person.pets.replace(["doo", "ggie", "gaga"])
      #   # => ActiveRecord::AssociationTypeMismatch: Pet expected, got String

      ##
      # :method: destroy_all
      # Deletes the records of the collection directly from the database.
      # This will _always_ remove the records ignoring the +:dependent+
      # option.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets.size # => 3
      #   person.pets
      #   # => [
      #   #       #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>,
      #   #       #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #       #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]
      #
      #   person.pets.destroy_all
      #
      #   person.pets.size # => 0
      #   person.pets      # => []
      #
      #   Pet.find(1) # => Couldn't find Pet with id=1

      ##
      # :method: destroy
      # Destroy the +records+ supplied and remove them from the collection.
      # This method will _always_ remove record from the database ignoring
      # the +:dependent+ option. Returns an array with the deleted records.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets.size # => 3
      #   person.pets
      #   # => [
      #   #       #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>,
      #   #       #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #       #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]
      #
      #   person.pets.destroy(Pet.find(1))
      #   # => [#<Pet id: 1, name: "Fancy-Fancy", person_id: 1>]
      #
      #   person.pets.size # => 2
      #   person.pets
      #   # => [
      #   #       #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #       #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]
      #
      #   person.pets.destroy(Pet.find(2), Pet.find(3))
      #   # => [
      #   #       #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #       #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]
      #
      #   person.pets.size # => 0
      #   person.pets      # => []
      #
      #   Pet.find([1, 2, 3]) # => ActiveRecord::RecordNotFound: Couldn't find all Pets with IDs (1, 2, 3)

      ##
      # :method: empty?
      # Returns true if the collection is empty.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets.count  # => 1
      #   person.pets.empty? # => false
      #
      #   person.pets.delete_all
      #
      #   person.pets.count  # => 0
      #   person.pets.empty? # => true
      
      ##
      # :method: any?
      # Returns true if the collection is not empty.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets.count # => 0
      #   person.pets.any?  # => false
      #
      #   person.pets << Pet.new(name: 'Snoop')
      #   person.pets.count # => 0
      #   person.pets.any?  # => true
      #
      # You can also pass a block to define criteria. The behaviour
      # is the same, it returns true if the collection based on the
      # criteria is not empty.
      #
      #   person.pets
      #   # => [#<Pet name: "Snoop", group: "dogs">]
      #
      #   person.pets.any? do |pet|
      #     pet.group == 'cats'
      #   end
      #   # => false
      #
      #   person.pets.any? do |pet|
      #     pet.group == 'dogs'
      #   end
      #   # => true

      ##
      # :method: many?
      # Returns true if the collection has more than one record.
      # Equivalent to +collection.size > 1+.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets.count #=> 1
      #   person.pets.many? #=> false
      #
      #   person.pets << Pet.new(name: 'Snoopy')
      #   person.pets.count #=> 2
      #   person.pets.many? #=> true
      #
      # You can also pass a block to define criteria. The
      # behaviour is the same, it returns true if the collection
      # based on the criteria has more than one record.
      #
      #   person.pets
      #   # => [
      #   #      #<Pet name: "Gorby", group: "cats">,
      #   #      #<Pet name: "Puff", group: "cats">,
      #   #      #<Pet name: "Snoop", group: "dogs">
      #   #    ]
      #
      #   person.pets.many? do |pet|
      #     pet.group == 'dogs'
      #   end
      #   # => false
      #
      #   person.pets.many? do |pet|
      #     pet.group == 'cats'
      #   end
      #   # => true

      ##
      # :method: include?
      # Returns true if the given object is present in the collection.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets # => [#<Pet id: 20, name: "Snoop">]
      #
      #   person.pets.include?(Pet.find(20)) # => true
      #   person.pets.include?(Pet.find(21)) # => false
      delegate :select, :find, :first, :last,
               :build, :create, :create!,
               :concat, :replace, :delete_all, :destroy_all, :delete, :destroy, :uniq,
               :sum, :count, :size, :length, :empty?,
               :any?, :many?, :include?,
               :to => :@association
  
      def initialize(association)
        @association = association
        super association.klass, association.klass.arel_table
        merge! association.scoped
      end

      alias_method :new, :build

      def proxy_association
        @association
      end

      # We don't want this object to be put on the scoping stack, because
      # that could create an infinite loop where we call an @association
      # method, which gets the current scope, which is this object, which
      # delegates to @association, and so on.
      def scoping
        @association.scoped.scoping { yield }
      end

      def spawn
        scoped
      end

      def scoped(options = nil)
        association = @association

        super.extending! do
          define_method(:proxy_association) { association }
        end
      end

      def ==(other)
        load_target == other
      end

      def to_ary
        load_target.dup
      end
      alias_method :to_a, :to_ary

      # Adds one or more +records+ to the collection by setting their foreign keys
      # to the association‘s primary key. Returns +self+, so several appends may be
      # chained together.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets.size # => 0
      #   person.pets << Pet.new(name: 'Fancy-Fancy')
      #   person.pets << [Pet.new(name: 'Spook'), Pet.new(name: 'Choo-Choo')]
      #   person.pets.size # => 3
      #
      #   person.id # => 1
      #   person.pets
      #   # => [
      #   #      #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>,
      #   #      #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #      #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]
      def <<(*records)
        proxy_association.concat(records) && self
      end
      alias_method :push, :<<

      # Removes every object from the collection. This does not destroy
      # the objects, it sets their foreign keys to +NULL+. Returns +self+
      # so methods can be chained.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets       # => [#<Pet id: 1, name: "Snoop", group: "dogs", person_id: 1>]
      #   person.pets.clear # => []
      #   person.pets.size  # => 0
      #
      #   Pet.find(1) # => #<Pet id: 1, name: "Snoop", group: "dogs", person_id: nil>
      #
      # If they are associated with +dependent: :destroy+ option, it deletes
      # them directly from the database.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets, dependent: :destroy
      #   end
      #
      #   person.pets       # => [#<Pet id: 2, name: "Gorby", group: "cats", person_id: 2>]
      #   person.pets.clear # => []
      #   person.pets.size  # => 0
      #
      #   Pet.find(2) # => ActiveRecord::RecordNotFound: Couldn't find Pet with id=2
      def clear
        delete_all
        self
      end

      def reload
        proxy_association.reload
        self
      end
    end
  end
end
