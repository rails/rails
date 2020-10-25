# frozen_string_literal: true

module ActiveRecord
  module Associations
    # Collection proxies in Active Record are middlemen between an
    # <tt>association</tt>, and its <tt>target</tt> result set.
    #
    # For example, given
    #
    #   class Blog < ActiveRecord::Base
    #     has_many :posts
    #   end
    #
    #   blog = Blog.first
    #
    # The collection proxy returned by <tt>blog.posts</tt> is built from a
    # <tt>:has_many</tt> <tt>association</tt>, and delegates to a collection
    # of posts as the <tt>target</tt>.
    #
    # This class delegates unknown methods to the <tt>association</tt>'s
    # relation class via a delegate cache.
    #
    # The <tt>target</tt> result set is not loaded until needed. For example,
    #
    #   blog.posts.count
    #
    # is computed directly through SQL and does not trigger by itself the
    # instantiation of the actual post records.
    class CollectionProxy < Relation
      def initialize(klass, association, **) #:nodoc:
        @association = association
        super klass

        extensions = association.extensions
        extend(*extensions) if extensions.any?
      end

      def target
        @association.target
      end

      def load_target
        @association.load_target
      end

      # Returns +true+ if the association has been loaded, otherwise +false+.
      #
      #   person.pets.loaded? # => false
      #   person.pets
      #   person.pets.loaded? # => true
      def loaded?
        @association.loaded?
      end
      alias :loaded :loaded?

      ##
      # :method: select
      #
      # :call-seq:
      #   select(*fields, &block)
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
      #   person.pets.select(:id, :name)
      #   # => [
      #   #      #<Pet id: 1, name: "Fancy-Fancy">,
      #   #      #<Pet id: 2, name: "Spook">,
      #   #      #<Pet id: 3, name: "Choo-Choo">
      #   #    ]
      #
      # Be careful because this also means you're initializing a model
      # object with only the fields that you've selected. If you attempt
      # to access a field except +id+ that is not in the initialized record you'll
      # receive:
      #
      #   person.pets.select(:name).first.person_id
      #   # => ActiveModel::MissingAttributeError: missing attribute: person_id
      #
      # *Second:* You can pass a block so it can be used just like Array#select.
      # This builds an array of objects from the database for the scope,
      # converting them into an array and iterating through them using
      # Array#select.
      #
      #   person.pets.select { |pet| /oo/.match?(pet.name) }
      #   # => [
      #   #      #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #      #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]

      # Finds an object in the collection responding to the +id+. Uses the same
      # rules as ActiveRecord::Base.find. Returns ActiveRecord::RecordNotFound
      # error if the object cannot be found.
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
      #   person.pets.find(4) # => ActiveRecord::RecordNotFound: Couldn't find Pet with 'id'=4
      #
      #   person.pets.find(2) { |pet| pet.name.downcase! }
      #   # => #<Pet id: 2, name: "fancy-fancy", person_id: 1>
      #
      #   person.pets.find(2, 3)
      #   # => [
      #   #       #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #       #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]
      def find(*args)
        return super if block_given?
        @association.find(*args)
      end

      ##
      # :method: first
      #
      # :call-seq:
      #   first(limit = nil)
      #
      # Returns the first record, or the first +n+ records, from the collection.
      # If the collection is empty, the first form returns +nil+, and the second
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
      # :method: second
      #
      # :call-seq:
      #   second()
      #
      # Same as #first except returns only the second record.

      ##
      # :method: third
      #
      # :call-seq:
      #   third()
      #
      # Same as #first except returns only the third record.

      ##
      # :method: fourth
      #
      # :call-seq:
      #   fourth()
      #
      # Same as #first except returns only the fourth record.

      ##
      # :method: fifth
      #
      # :call-seq:
      #   fifth()
      #
      # Same as #first except returns only the fifth record.

      ##
      # :method: forty_two
      #
      # :call-seq:
      #   forty_two()
      #
      # Same as #first except returns only the forty second record.
      # Also known as accessing "the reddit".

      ##
      # :method: third_to_last
      #
      # :call-seq:
      #   third_to_last()
      #
      # Same as #first except returns only the third-to-last record.

      ##
      # :method: second_to_last
      #
      # :call-seq:
      #   second_to_last()
      #
      # Same as #first except returns only the second-to-last record.

      # Returns the last record, or the last +n+ records, from the collection.
      # If the collection is empty, the first form returns +nil+, and the second
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
      def last(limit = nil)
        load_target if find_from_target?
        super
      end

      # Gives a record (or N records if a parameter is supplied) from the collection
      # using the same rules as <tt>ActiveRecord::Base.take</tt>.
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
      #   person.pets.take # => #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>
      #
      #   person.pets.take(2)
      #   # => [
      #   #      #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>,
      #   #      #<Pet id: 2, name: "Spook", person_id: 1>
      #   #    ]
      #
      #   another_person_without.pets         # => []
      #   another_person_without.pets.take    # => nil
      #   another_person_without.pets.take(2) # => []
      def take(limit = nil)
        load_target if find_from_target?
        super
      end

      # Returns a new object of the collection type that has been instantiated
      # with +attributes+ and linked to this object, but have not yet been saved.
      # You can pass an array of attributes hashes, this will return an array
      # with the new objects.
      #
      #   class Person
      #     has_many :pets
      #   end
      #
      #   person.pets.build
      #   # => #<Pet id: nil, name: nil, person_id: 1>
      #
      #   person.pets.build(name: 'Fancy-Fancy')
      #   # => #<Pet id: nil, name: "Fancy-Fancy", person_id: 1>
      #
      #   person.pets.build([{name: 'Spook'}, {name: 'Choo-Choo'}, {name: 'Brain'}])
      #   # => [
      #   #      #<Pet id: nil, name: "Spook", person_id: 1>,
      #   #      #<Pet id: nil, name: "Choo-Choo", person_id: 1>,
      #   #      #<Pet id: nil, name: "Brain", person_id: 1>
      #   #    ]
      #
      #   person.pets.size  # => 5 # size of the collection
      #   person.pets.count # => 0 # count from database
      def build(attributes = {}, &block)
        @association.build(attributes, &block)
      end
      alias_method :new, :build

      # Returns a new object of the collection type that has been instantiated with
      # attributes, linked to this object and that has already been saved (if it
      # passes the validations).
      #
      #   class Person
      #     has_many :pets
      #   end
      #
      #   person.pets.create(name: 'Fancy-Fancy')
      #   # => #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>
      #
      #   person.pets.create([{name: 'Spook'}, {name: 'Choo-Choo'}])
      #   # => [
      #   #      #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #      #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]
      #
      #   person.pets.size  # => 3
      #   person.pets.count # => 3
      #
      #   person.pets.find(1, 2, 3)
      #   # => [
      #   #       #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>,
      #   #       #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #       #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]
      def create(attributes = {}, &block)
        @association.create(attributes, &block)
      end

      # Like #create, except that if the record is invalid, raises an exception.
      #
      #   class Person
      #     has_many :pets
      #   end
      #
      #   class Pet
      #     validates :name, presence: true
      #   end
      #
      #   person.pets.create!(name: nil)
      #   # => ActiveRecord::RecordInvalid: Validation failed: Name can't be blank
      def create!(attributes = {}, &block)
        @association.create!(attributes, &block)
      end

      # Replaces this collection with +other_array+. This will perform a diff
      # and delete/add only records that have changed.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets
      #   # => [#<Pet id: 1, name: "Gorby", group: "cats", person_id: 1>]
      #
      #   other_pets = [Pet.new(name: 'Puff', group: 'celebrities')]
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
      def replace(other_array)
        @association.replace(other_array)
      end

      # Deletes all the records from the collection according to the strategy
      # specified by the +:dependent+ option. If no +:dependent+ option is given,
      # then it will follow the default strategy.
      #
      # For <tt>has_many :through</tt> associations, the default deletion strategy is
      # +:delete_all+.
      #
      # For +has_many+ associations, the default deletion strategy is +:nullify+.
      # This sets the foreign keys to +NULL+.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets # dependent: :nullify option by default
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
      #   person.pets.delete_all
      #   # => [
      #   #       #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>,
      #   #       #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #       #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]
      #
      #   person.pets.size # => 0
      #   person.pets      # => []
      #
      #   Pet.find(1, 2, 3)
      #   # => [
      #   #       #<Pet id: 1, name: "Fancy-Fancy", person_id: nil>,
      #   #       #<Pet id: 2, name: "Spook", person_id: nil>,
      #   #       #<Pet id: 3, name: "Choo-Choo", person_id: nil>
      #   #    ]
      #
      # Both +has_many+ and <tt>has_many :through</tt> dependencies default to the
      # +:delete_all+ strategy if the +:dependent+ option is set to +:destroy+.
      # Records are not instantiated and callbacks will not be fired.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets, dependent: :destroy
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
      #   person.pets.delete_all
      #
      #   Pet.find(1, 2, 3)
      #   # => ActiveRecord::RecordNotFound: Couldn't find all Pets with 'id': (1, 2, 3)
      #
      # If it is set to <tt>:delete_all</tt>, all the objects are deleted
      # *without* calling their +destroy+ method.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets, dependent: :delete_all
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
      #   person.pets.delete_all
      #
      #   Pet.find(1, 2, 3)
      #   # => ActiveRecord::RecordNotFound: Couldn't find all Pets with 'id': (1, 2, 3)
      def delete_all(dependent = nil)
        @association.delete_all(dependent).tap { reset_scope }
      end

      # Deletes the records of the collection directly from the database
      # ignoring the +:dependent+ option. Records are instantiated and it
      # invokes +before_remove+, +after_remove+ , +before_destroy+ and
      # +after_destroy+ callbacks.
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
      def destroy_all
        @association.destroy_all.tap { reset_scope }
      end

      # Deletes the +records+ supplied from the collection according to the strategy
      # specified by the +:dependent+ option. If no +:dependent+ option is given,
      # then it will follow the default strategy. Returns an array with the
      # deleted records.
      #
      # For <tt>has_many :through</tt> associations, the default deletion strategy is
      # +:delete_all+.
      #
      # For +has_many+ associations, the default deletion strategy is +:nullify+.
      # This sets the foreign keys to +NULL+.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets # dependent: :nullify option by default
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
      #   person.pets.delete(Pet.find(1))
      #   # => [#<Pet id: 1, name: "Fancy-Fancy", person_id: 1>]
      #
      #   person.pets.size # => 2
      #   person.pets
      #   # => [
      #   #       #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #       #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]
      #
      #   Pet.find(1)
      #   # => #<Pet id: 1, name: "Fancy-Fancy", person_id: nil>
      #
      # If it is set to <tt>:destroy</tt> all the +records+ are removed by calling
      # their +destroy+ method. See +destroy+ for more information.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets, dependent: :destroy
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
      #   person.pets.delete(Pet.find(1), Pet.find(3))
      #   # => [
      #   #       #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>,
      #   #       #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]
      #
      #   person.pets.size # => 1
      #   person.pets
      #   # => [#<Pet id: 2, name: "Spook", person_id: 1>]
      #
      #   Pet.find(1, 3)
      #   # => ActiveRecord::RecordNotFound: Couldn't find all Pets with 'id': (1, 3)
      #
      # If it is set to <tt>:delete_all</tt>, all the +records+ are deleted
      # *without* calling their +destroy+ method.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets, dependent: :delete_all
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
      #   person.pets.delete(Pet.find(1))
      #   # => [#<Pet id: 1, name: "Fancy-Fancy", person_id: 1>]
      #
      #   person.pets.size # => 2
      #   person.pets
      #   # => [
      #   #       #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #       #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]
      #
      #   Pet.find(1)
      #   # => ActiveRecord::RecordNotFound: Couldn't find Pet with 'id'=1
      #
      # You can pass +Integer+ or +String+ values, it finds the records
      # responding to the +id+ and executes delete on them.
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
      #   person.pets.delete("1")
      #   # => [#<Pet id: 1, name: "Fancy-Fancy", person_id: 1>]
      #
      #   person.pets.delete(2, 3)
      #   # => [
      #   #       #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #       #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]
      def delete(*records)
        @association.delete(*records).tap { reset_scope }
      end

      # Destroys the +records+ supplied and removes them from the collection.
      # This method will _always_ remove record from the database ignoring
      # the +:dependent+ option. Returns an array with the removed records.
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
      #   person.pets.size  # => 0
      #   person.pets       # => []
      #
      #   Pet.find(1, 2, 3) # => ActiveRecord::RecordNotFound: Couldn't find all Pets with 'id': (1, 2, 3)
      #
      # You can pass +Integer+ or +String+ values, it finds the records
      # responding to the +id+ and then deletes them from the database.
      #
      #   person.pets.size # => 3
      #   person.pets
      #   # => [
      #   #       #<Pet id: 4, name: "Benny", person_id: 1>,
      #   #       #<Pet id: 5, name: "Brain", person_id: 1>,
      #   #       #<Pet id: 6, name: "Boss",  person_id: 1>
      #   #    ]
      #
      #   person.pets.destroy("4")
      #   # => #<Pet id: 4, name: "Benny", person_id: 1>
      #
      #   person.pets.size # => 2
      #   person.pets
      #   # => [
      #   #       #<Pet id: 5, name: "Brain", person_id: 1>,
      #   #       #<Pet id: 6, name: "Boss",  person_id: 1>
      #   #    ]
      #
      #   person.pets.destroy(5, 6)
      #   # => [
      #   #       #<Pet id: 5, name: "Brain", person_id: 1>,
      #   #       #<Pet id: 6, name: "Boss",  person_id: 1>
      #   #    ]
      #
      #   person.pets.size  # => 0
      #   person.pets       # => []
      #
      #   Pet.find(4, 5, 6) # => ActiveRecord::RecordNotFound: Couldn't find all Pets with 'id': (4, 5, 6)
      def destroy(*records)
        @association.destroy(*records).tap { reset_scope }
      end

      ##
      # :method: distinct
      #
      # :call-seq:
      #   distinct(value = true)
      #
      # Specifies whether the records should be unique or not.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets.select(:name)
      #   # => [
      #   #      #<Pet name: "Fancy-Fancy">,
      #   #      #<Pet name: "Fancy-Fancy">
      #   #    ]
      #
      #   person.pets.select(:name).distinct
      #   # => [#<Pet name: "Fancy-Fancy">]
      #
      #   person.pets.select(:name).distinct.distinct(false)
      #   # => [
      #   #      #<Pet name: "Fancy-Fancy">,
      #   #      #<Pet name: "Fancy-Fancy">
      #   #    ]

      #--
      def calculate(operation, column_name)
        null_scope? ? scope.calculate(operation, column_name) : super
      end

      def pluck(*column_names)
        null_scope? ? scope.pluck(*column_names) : super
      end

      ##
      # :method: count
      #
      # :call-seq:
      #   count(column_name = nil, &block)
      #
      # Count all records.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   # This will perform the count using SQL.
      #   person.pets.count # => 3
      #   person.pets
      #   # => [
      #   #       #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>,
      #   #       #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #       #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]
      #
      # Passing a block will select all of a person's pets in SQL and then
      # perform the count using Ruby.
      #
      #   person.pets.count { |pet| pet.name.include?('-') } # => 2

      # Returns the size of the collection. If the collection hasn't been loaded,
      # it executes a <tt>SELECT COUNT(*)</tt> query. Else it calls <tt>collection.size</tt>.
      #
      # If the collection has been already loaded +size+ and +length+ are
      # equivalent. If not and you are going to need the records anyway
      # +length+ will take one less query. Otherwise +size+ is more efficient.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets.size # => 3
      #   # executes something like SELECT COUNT(*) FROM "pets" WHERE "pets"."person_id" = 1
      #
      #   person.pets # This will execute a SELECT * FROM query
      #   # => [
      #   #       #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>,
      #   #       #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #       #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]
      #
      #   person.pets.size # => 3
      #   # Because the collection is already loaded, this will behave like
      #   # collection.size and no SQL count query is executed.
      def size
        @association.size
      end

      ##
      # :method: length
      #
      # :call-seq:
      #   length()
      #
      # Returns the size of the collection calling +size+ on the target.
      # If the collection has been already loaded, +length+ and +size+ are
      # equivalent. If not and you are going to need the records anyway this
      # method will take one less query. Otherwise +size+ is more efficient.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets.length # => 3
      #   # executes something like SELECT "pets".* FROM "pets" WHERE "pets"."person_id" = 1
      #
      #   # Because the collection is loaded, you can
      #   # call the collection with no additional queries:
      #   person.pets
      #   # => [
      #   #       #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>,
      #   #       #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #       #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]

      # Returns +true+ if the collection is empty. If the collection has been
      # loaded it is equivalent
      # to <tt>collection.size.zero?</tt>. If the collection has not been loaded,
      # it is equivalent to <tt>!collection.exists?</tt>. If the collection has
      # not already been loaded and you are going to fetch the records anyway it
      # is better to check <tt>collection.length.zero?</tt>.
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
      def empty?
        @association.empty?
      end

      ##
      # :method: any?
      #
      # :call-seq:
      #   any?()
      #
      # Returns +true+ if the collection is not empty.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets.count # => 0
      #   person.pets.any?  # => false
      #
      #   person.pets << Pet.new(name: 'Snoop')
      #   person.pets.count # => 1
      #   person.pets.any?  # => true
      #
      # You can also pass a +block+ to define criteria. The behavior
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
      #
      # :call-seq:
      #   many?()
      #
      # Returns true if the collection has more than one record.
      # Equivalent to <tt>collection.size > 1</tt>.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets.count # => 1
      #   person.pets.many? # => false
      #
      #   person.pets << Pet.new(name: 'Snoopy')
      #   person.pets.count # => 2
      #   person.pets.many? # => true
      #
      # You can also pass a +block+ to define criteria. The
      # behavior is the same, it returns true if the collection
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

      # Returns +true+ if the given +record+ is present in the collection.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets # => [#<Pet id: 20, name: "Snoop">]
      #
      #   person.pets.include?(Pet.find(20)) # => true
      #   person.pets.include?(Pet.find(21)) # => false
      def include?(record)
        !!@association.include?(record)
      end

      def proxy_association # :nodoc:
        @association
      end

      # Returns a <tt>Relation</tt> object for the records in this association
      def scope
        @scope ||= @association.scope
      end

      # Equivalent to <tt>Array#==</tt>. Returns +true+ if the two arrays
      # contain the same number of elements and if each element is equal
      # to the corresponding element in the +other+ array, otherwise returns
      # +false+.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets
      #   # => [
      #   #      #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>,
      #   #      #<Pet id: 2, name: "Spook", person_id: 1>
      #   #    ]
      #
      #   other = person.pets.to_ary
      #
      #   person.pets == other
      #   # => true
      #
      #   other = [Pet.new(id: 1), Pet.new(id: 2)]
      #
      #   person.pets == other
      #   # => false
      def ==(other)
        load_target == other
      end

      ##
      # :method: to_ary
      #
      # :call-seq:
      #   to_ary()
      #
      # Returns a new array of objects from the collection. If the collection
      # hasn't been loaded, it fetches the records from the database.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets
      #   # => [
      #   #       #<Pet id: 4, name: "Benny", person_id: 1>,
      #   #       #<Pet id: 5, name: "Brain", person_id: 1>,
      #   #       #<Pet id: 6, name: "Boss",  person_id: 1>
      #   #    ]
      #
      #   other_pets = person.pets.to_ary
      #   # => [
      #   #       #<Pet id: 4, name: "Benny", person_id: 1>,
      #   #       #<Pet id: 5, name: "Brain", person_id: 1>,
      #   #       #<Pet id: 6, name: "Boss",  person_id: 1>
      #   #    ]
      #
      #   other_pets.replace([Pet.new(name: 'BooGoo')])
      #
      #   other_pets
      #   # => [#<Pet id: nil, name: "BooGoo", person_id: 1>]
      #
      #   person.pets
      #   # This is not affected by replace
      #   # => [
      #   #       #<Pet id: 4, name: "Benny", person_id: 1>,
      #   #       #<Pet id: 5, name: "Brain", person_id: 1>,
      #   #       #<Pet id: 6, name: "Boss",  person_id: 1>
      #   #    ]

      def records # :nodoc:
        load_target
      end

      # Adds one or more +records+ to the collection by setting their foreign keys
      # to the association's primary key. Since <tt><<</tt> flattens its argument list and
      # inserts each record, +push+ and +concat+ behave identically. Returns +self+
      # so several appends may be chained together.
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
      alias_method :append, :<<
      alias_method :concat, :<<

      def prepend(*args) # :nodoc:
        raise NoMethodError, "prepend on association is not defined. Please use <<, push or append"
      end

      # Equivalent to +delete_all+. The difference is that returns +self+, instead
      # of an array with the deleted objects, so methods can be chained. See
      # +delete_all+ for more information.
      # Note that because +delete_all+ removes records by directly
      # running an SQL query into the database, the +updated_at+ column of
      # the object is not changed.
      def clear
        delete_all
        self
      end

      # Reloads the collection from the database. Returns +self+.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets # fetches pets from the database
      #   # => [#<Pet id: 1, name: "Snoop", group: "dogs", person_id: 1>]
      #
      #   person.pets # uses the pets cache
      #   # => [#<Pet id: 1, name: "Snoop", group: "dogs", person_id: 1>]
      #
      #   person.pets.reload # fetches pets from the database
      #   # => [#<Pet id: 1, name: "Snoop", group: "dogs", person_id: 1>]
      def reload
        proxy_association.reload(true)
        reset_scope
      end

      # Unloads the association. Returns +self+.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets # fetches pets from the database
      #   # => [#<Pet id: 1, name: "Snoop", group: "dogs", person_id: 1>]
      #
      #   person.pets # uses the pets cache
      #   # => [#<Pet id: 1, name: "Snoop", group: "dogs", person_id: 1>]
      #
      #   person.pets.reset # clears the pets cache
      #
      #   person.pets  # fetches pets from the database
      #   # => [#<Pet id: 1, name: "Snoop", group: "dogs", person_id: 1>]
      def reset
        proxy_association.reset
        proxy_association.reset_scope
        reset_scope
      end

      def reset_scope # :nodoc:
        @offsets = @take = nil
        @scope = nil
        self
      end

      def inspect # :nodoc:
        load_target if find_from_target?
        super
      end

      delegate_methods = [
        QueryMethods,
        SpawnMethods,
      ].flat_map { |klass|
        klass.public_instance_methods(false)
      } - self.public_instance_methods(false) - [:select] + [
        :scoping, :values, :insert, :insert_all, :insert!, :insert_all!, :upsert, :upsert_all
      ]

      delegate(*delegate_methods, to: :scope)

      private
        def find_nth_with_limit(index, limit)
          load_target if find_from_target?
          super
        end

        def find_nth_from_last(index)
          load_target if find_from_target?
          super
        end

        def null_scope?
          @association.null_scope?
        end

        def find_from_target?
          @association.find_from_target?
        end

        def exec_queries
          load_target
        end
    end
  end
end
