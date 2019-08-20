# frozen_string_literal: true

require "active_support/core_ext/enumerable"
require "active_support/core_ext/string/conversions"
require "active_support/core_ext/module/remove_method"
require "active_record/errors"

module ActiveRecord
  class AssociationNotFoundError < ConfigurationError #:nodoc:
    def initialize(record = nil, association_name = nil)
      if record && association_name
        super("Association named '#{association_name}' was not found on #{record.class.name}; perhaps you misspelled it?")
      else
        super("Association was not found.")
      end
    end
  end

  class InverseOfAssociationNotFoundError < ActiveRecordError #:nodoc:
    def initialize(reflection = nil, associated_class = nil)
      if reflection
        super("Could not find the inverse association for #{reflection.name} (#{reflection.options[:inverse_of].inspect} in #{associated_class.nil? ? reflection.class_name : associated_class.name})")
      else
        super("Could not find the inverse association.")
      end
    end
  end

  class HasManyThroughAssociationNotFoundError < ActiveRecordError #:nodoc:
    def initialize(owner_class_name = nil, reflection = nil)
      if owner_class_name && reflection
        super("Could not find the association #{reflection.options[:through].inspect} in model #{owner_class_name}")
      else
        super("Could not find the association.")
      end
    end
  end

  class HasManyThroughAssociationPolymorphicSourceError < ActiveRecordError #:nodoc:
    def initialize(owner_class_name = nil, reflection = nil, source_reflection = nil)
      if owner_class_name && reflection && source_reflection
        super("Cannot have a has_many :through association '#{owner_class_name}##{reflection.name}' on the polymorphic object '#{source_reflection.class_name}##{source_reflection.name}' without 'source_type'. Try adding 'source_type: \"#{reflection.name.to_s.classify}\"' to 'has_many :through' definition.")
      else
        super("Cannot have a has_many :through association.")
      end
    end
  end

  class HasManyThroughAssociationPolymorphicThroughError < ActiveRecordError #:nodoc:
    def initialize(owner_class_name = nil, reflection = nil)
      if owner_class_name && reflection
        super("Cannot have a has_many :through association '#{owner_class_name}##{reflection.name}' which goes through the polymorphic association '#{owner_class_name}##{reflection.through_reflection.name}'.")
      else
        super("Cannot have a has_many :through association.")
      end
    end
  end

  class HasManyThroughAssociationPointlessSourceTypeError < ActiveRecordError #:nodoc:
    def initialize(owner_class_name = nil, reflection = nil, source_reflection = nil)
      if owner_class_name && reflection && source_reflection
        super("Cannot have a has_many :through association '#{owner_class_name}##{reflection.name}' with a :source_type option if the '#{reflection.through_reflection.class_name}##{source_reflection.name}' is not polymorphic. Try removing :source_type on your association.")
      else
        super("Cannot have a has_many :through association.")
      end
    end
  end

  class HasOneThroughCantAssociateThroughCollection < ActiveRecordError #:nodoc:
    def initialize(owner_class_name = nil, reflection = nil, through_reflection = nil)
      if owner_class_name && reflection && through_reflection
        super("Cannot have a has_one :through association '#{owner_class_name}##{reflection.name}' where the :through association '#{owner_class_name}##{through_reflection.name}' is a collection. Specify a has_one or belongs_to association in the :through option instead.")
      else
        super("Cannot have a has_one :through association.")
      end
    end
  end

  class HasOneAssociationPolymorphicThroughError < ActiveRecordError #:nodoc:
    def initialize(owner_class_name = nil, reflection = nil)
      if owner_class_name && reflection
        super("Cannot have a has_one :through association '#{owner_class_name}##{reflection.name}' which goes through the polymorphic association '#{owner_class_name}##{reflection.through_reflection.name}'.")
      else
        super("Cannot have a has_one :through association.")
      end
    end
  end

  class HasManyThroughSourceAssociationNotFoundError < ActiveRecordError #:nodoc:
    def initialize(reflection = nil)
      if reflection
        through_reflection      = reflection.through_reflection
        source_reflection_names = reflection.source_reflection_names
        source_associations     = reflection.through_reflection.klass._reflections.keys
        super("Could not find the source association(s) #{source_reflection_names.collect(&:inspect).to_sentence(two_words_connector: ' or ', last_word_connector: ', or ', locale: :en)} in model #{through_reflection.klass}. Try 'has_many #{reflection.name.inspect}, :through => #{through_reflection.name.inspect}, :source => <name>'. Is it one of #{source_associations.to_sentence(two_words_connector: ' or ', last_word_connector: ', or ', locale: :en)}?")
      else
        super("Could not find the source association(s).")
      end
    end
  end

  class HasManyThroughOrderError < ActiveRecordError #:nodoc:
    def initialize(owner_class_name = nil, reflection = nil, through_reflection = nil)
      if owner_class_name && reflection && through_reflection
        super("Cannot have a has_many :through association '#{owner_class_name}##{reflection.name}' which goes through '#{owner_class_name}##{through_reflection.name}' before the through association is defined.")
      else
        super("Cannot have a has_many :through association before the through association is defined.")
      end
    end
  end

  class ThroughCantAssociateThroughHasOneOrManyReflection < ActiveRecordError #:nodoc:
    def initialize(owner = nil, reflection = nil)
      if owner && reflection
        super("Cannot modify association '#{owner.class.name}##{reflection.name}' because the source reflection class '#{reflection.source_reflection.class_name}' is associated to '#{reflection.through_reflection.class_name}' via :#{reflection.source_reflection.macro}.")
      else
        super("Cannot modify association.")
      end
    end
  end

  class AmbiguousSourceReflectionForThroughAssociation < ActiveRecordError # :nodoc:
    def initialize(klass, macro, association_name, options, possible_sources)
      example_options = options.dup
      example_options[:source] = possible_sources.first

      super("Ambiguous source reflection for through association. Please " \
            "specify a :source directive on your declaration like:\n" \
            "\n" \
            "  class #{klass} < ActiveRecord::Base\n" \
            "    #{macro} :#{association_name}, #{example_options}\n" \
            "  end"
           )
    end
  end

  class HasManyThroughCantAssociateThroughHasOneOrManyReflection < ThroughCantAssociateThroughHasOneOrManyReflection #:nodoc:
  end

  class HasOneThroughCantAssociateThroughHasOneOrManyReflection < ThroughCantAssociateThroughHasOneOrManyReflection #:nodoc:
  end

  class ThroughNestedAssociationsAreReadonly < ActiveRecordError #:nodoc:
    def initialize(owner = nil, reflection = nil)
      if owner && reflection
        super("Cannot modify association '#{owner.class.name}##{reflection.name}' because it goes through more than one other association.")
      else
        super("Through nested associations are read-only.")
      end
    end
  end

  class HasManyThroughNestedAssociationsAreReadonly < ThroughNestedAssociationsAreReadonly #:nodoc:
  end

  class HasOneThroughNestedAssociationsAreReadonly < ThroughNestedAssociationsAreReadonly #:nodoc:
  end

  # This error is raised when trying to eager load a polymorphic association using a JOIN.
  # Eager loading polymorphic associations is only possible with
  # {ActiveRecord::Relation#preload}[rdoc-ref:QueryMethods#preload].
  class EagerLoadPolymorphicError < ActiveRecordError
    def initialize(reflection = nil)
      if reflection
        super("Cannot eagerly load the polymorphic association #{reflection.name.inspect}")
      else
        super("Eager load polymorphic error.")
      end
    end
  end

  # This error is raised when trying to destroy a parent instance in N:1 or 1:1 associations
  # (has_many, has_one) when there is at least 1 child associated instance.
  # ex: if @project.tasks.size > 0, DeleteRestrictionError will be raised when trying to destroy @project
  class DeleteRestrictionError < ActiveRecordError #:nodoc:
    def initialize(name = nil)
      if name
        super("Cannot delete record because of dependent #{name}")
      else
        super("Delete restriction error.")
      end
    end
  end

  # See ActiveRecord::Associations::ClassMethods for documentation.
  module Associations # :nodoc:
    extend ActiveSupport::Autoload
    extend ActiveSupport::Concern

    # These classes will be loaded when associations are created.
    # So there is no need to eager load them.
    autoload :Association
    autoload :SingularAssociation
    autoload :CollectionAssociation
    autoload :ForeignAssociation
    autoload :CollectionProxy
    autoload :ThroughAssociation

    module Builder #:nodoc:
      autoload :Association,           "active_record/associations/builder/association"
      autoload :SingularAssociation,   "active_record/associations/builder/singular_association"
      autoload :CollectionAssociation, "active_record/associations/builder/collection_association"

      autoload :BelongsTo,           "active_record/associations/builder/belongs_to"
      autoload :HasOne,              "active_record/associations/builder/has_one"
      autoload :HasMany,             "active_record/associations/builder/has_many"
      autoload :HasAndBelongsToMany, "active_record/associations/builder/has_and_belongs_to_many"
    end

    eager_autoload do
      autoload :BelongsToAssociation
      autoload :BelongsToPolymorphicAssociation
      autoload :HasManyAssociation
      autoload :HasManyThroughAssociation
      autoload :HasOneAssociation
      autoload :HasOneThroughAssociation

      autoload :Preloader
      autoload :JoinDependency
      autoload :AssociationScope
      autoload :AliasTracker
    end

    def self.eager_load!
      super
      Preloader.eager_load!
    end

    # Returns the association instance for the given name, instantiating it if it doesn't already exist
    def association(name) #:nodoc:
      association = association_instance_get(name)

      if association.nil?
        unless reflection = self.class._reflect_on_association(name)
          raise AssociationNotFoundError.new(self, name)
        end
        association = reflection.association_class.new(self, reflection)
        association_instance_set(name, association)
      end

      association
    end

    def association_cached?(name) # :nodoc:
      @association_cache.key?(name)
    end

    def initialize_dup(*) # :nodoc:
      @association_cache = {}
      super
    end

    def reload(*) # :nodoc:
      clear_association_cache
      super
    end

    private
      # Clears out the association cache.
      def clear_association_cache
        @association_cache.clear if persisted?
      end

      def init_internals
        @association_cache = {}
        super
      end

      # Returns the specified association instance if it exists, +nil+ otherwise.
      def association_instance_get(name)
        @association_cache[name]
      end

      # Set the specified association instance.
      def association_instance_set(name, association)
        @association_cache[name] = association
      end

      # \Associations are a set of macro-like class methods for tying objects together through
      # foreign keys. They express relationships like "Project has one Project Manager"
      # or "Project belongs to a Portfolio". Each macro adds a number of methods to the
      # class which are specialized according to the collection or association symbol and the
      # options hash. It works much the same way as Ruby's own <tt>attr*</tt>
      # methods.
      #
      #   class Project < ActiveRecord::Base
      #     belongs_to              :portfolio
      #     has_one                 :project_manager
      #     has_many                :milestones
      #     has_and_belongs_to_many :categories
      #   end
      #
      # The project class now has the following methods (and more) to ease the traversal and
      # manipulation of its relationships:
      # * <tt>Project#portfolio</tt>, <tt>Project#portfolio=(portfolio)</tt>, <tt>Project#reload_portfolio</tt>
      # * <tt>Project#project_manager</tt>, <tt>Project#project_manager=(project_manager)</tt>, <tt>Project#reload_project_manager</tt>
      # * <tt>Project#milestones.empty?</tt>, <tt>Project#milestones.size</tt>, <tt>Project#milestones</tt>, <tt>Project#milestones<<(milestone)</tt>,
      #   <tt>Project#milestones.delete(milestone)</tt>, <tt>Project#milestones.destroy(milestone)</tt>, <tt>Project#milestones.find(milestone_id)</tt>,
      #   <tt>Project#milestones.build</tt>, <tt>Project#milestones.create</tt>
      # * <tt>Project#categories.empty?</tt>, <tt>Project#categories.size</tt>, <tt>Project#categories</tt>, <tt>Project#categories<<(category1)</tt>,
      #   <tt>Project#categories.delete(category1)</tt>, <tt>Project#categories.destroy(category1)</tt>
      #
      # === A word of warning
      #
      # Don't create associations that have the same name as {instance methods}[rdoc-ref:ActiveRecord::Core] of
      # <tt>ActiveRecord::Base</tt>. Since the association adds a method with that name to
      # its model, using an association with the same name as one provided by <tt>ActiveRecord::Base</tt> will override the method inherited through <tt>ActiveRecord::Base</tt> and will break things.
      # For instance, +attributes+ and +connection+ would be bad choices for association names, because those names already exist in the list of <tt>ActiveRecord::Base</tt> instance methods.
      #
      # == Auto-generated methods
      # See also Instance Public methods below for more details.
      #
      # === Singular associations (one-to-one)
      #                                     |            |  belongs_to  |
      #   generated methods                 | belongs_to | :polymorphic | has_one
      #   ----------------------------------+------------+--------------+---------
      #   other                             |     X      |      X       |    X
      #   other=(other)                     |     X      |      X       |    X
      #   build_other(attributes={})        |     X      |              |    X
      #   create_other(attributes={})       |     X      |              |    X
      #   create_other!(attributes={})      |     X      |              |    X
      #   reload_other                      |     X      |      X       |    X
      #
      # === Collection associations (one-to-many / many-to-many)
      #                                     |       |          | has_many
      #   generated methods                 | habtm | has_many | :through
      #   ----------------------------------+-------+----------+----------
      #   others                            |   X   |    X     |    X
      #   others=(other,other,...)          |   X   |    X     |    X
      #   other_ids                         |   X   |    X     |    X
      #   other_ids=(id,id,...)             |   X   |    X     |    X
      #   others<<                          |   X   |    X     |    X
      #   others.push                       |   X   |    X     |    X
      #   others.concat                     |   X   |    X     |    X
      #   others.build(attributes={})       |   X   |    X     |    X
      #   others.create(attributes={})      |   X   |    X     |    X
      #   others.create!(attributes={})     |   X   |    X     |    X
      #   others.size                       |   X   |    X     |    X
      #   others.length                     |   X   |    X     |    X
      #   others.count                      |   X   |    X     |    X
      #   others.sum(*args)                 |   X   |    X     |    X
      #   others.empty?                     |   X   |    X     |    X
      #   others.clear                      |   X   |    X     |    X
      #   others.delete(other,other,...)    |   X   |    X     |    X
      #   others.delete_all                 |   X   |    X     |    X
      #   others.destroy(other,other,...)   |   X   |    X     |    X
      #   others.destroy_all                |   X   |    X     |    X
      #   others.find(*args)                |   X   |    X     |    X
      #   others.exists?                    |   X   |    X     |    X
      #   others.distinct                   |   X   |    X     |    X
      #   others.reset                      |   X   |    X     |    X
      #   others.reload                     |   X   |    X     |    X
      #
      # === Overriding generated methods
      #
      # Association methods are generated in a module included into the model
      # class, making overrides easy. The original generated method can thus be
      # called with +super+:
      #
      #   class Car < ActiveRecord::Base
      #     belongs_to :owner
      #     belongs_to :old_owner
      #
      #     def owner=(new_owner)
      #       self.old_owner = self.owner
      #       super
      #     end
      #   end
      #
      # The association methods module is included immediately after the
      # generated attributes methods module, meaning an association will
      # override the methods for an attribute with the same name.
      #
      # == Cardinality and associations
      #
      # Active Record associations can be used to describe one-to-one, one-to-many and many-to-many
      # relationships between models. Each model uses an association to describe its role in
      # the relation. The #belongs_to association is always used in the model that has
      # the foreign key.
      #
      # === One-to-one
      #
      # Use #has_one in the base, and #belongs_to in the associated model.
      #
      #   class Employee < ActiveRecord::Base
      #     has_one :office
      #   end
      #   class Office < ActiveRecord::Base
      #     belongs_to :employee    # foreign key - employee_id
      #   end
      #
      # === One-to-many
      #
      # Use #has_many in the base, and #belongs_to in the associated model.
      #
      #   class Manager < ActiveRecord::Base
      #     has_many :employees
      #   end
      #   class Employee < ActiveRecord::Base
      #     belongs_to :manager     # foreign key - manager_id
      #   end
      #
      # === Many-to-many
      #
      # There are two ways to build a many-to-many relationship.
      #
      # The first way uses a #has_many association with the <tt>:through</tt> option and a join model, so
      # there are two stages of associations.
      #
      #   class Assignment < ActiveRecord::Base
      #     belongs_to :programmer  # foreign key - programmer_id
      #     belongs_to :project     # foreign key - project_id
      #   end
      #   class Programmer < ActiveRecord::Base
      #     has_many :assignments
      #     has_many :projects, through: :assignments
      #   end
      #   class Project < ActiveRecord::Base
      #     has_many :assignments
      #     has_many :programmers, through: :assignments
      #   end
      #
      # For the second way, use #has_and_belongs_to_many in both models. This requires a join table
      # that has no corresponding model or primary key.
      #
      #   class Programmer < ActiveRecord::Base
      #     has_and_belongs_to_many :projects       # foreign keys in the join table
      #   end
      #   class Project < ActiveRecord::Base
      #     has_and_belongs_to_many :programmers    # foreign keys in the join table
      #   end
      #
      # Choosing which way to build a many-to-many relationship is not always simple.
      # If you need to work with the relationship model as its own entity,
      # use #has_many <tt>:through</tt>. Use #has_and_belongs_to_many when working with legacy schemas or when
      # you never work directly with the relationship itself.
      #
      # == Is it a #belongs_to or #has_one association?
      #
      # Both express a 1-1 relationship. The difference is mostly where to place the foreign
      # key, which goes on the table for the class declaring the #belongs_to relationship.
      #
      #   class User < ActiveRecord::Base
      #     # I reference an account.
      #     belongs_to :account
      #   end
      #
      #   class Account < ActiveRecord::Base
      #     # One user references me.
      #     has_one :user
      #   end
      #
      # The tables for these classes could look something like:
      #
      #   CREATE TABLE users (
      #     id bigint NOT NULL auto_increment,
      #     account_id bigint default NULL,
      #     name varchar default NULL,
      #     PRIMARY KEY  (id)
      #   )
      #
      #   CREATE TABLE accounts (
      #     id bigint NOT NULL auto_increment,
      #     name varchar default NULL,
      #     PRIMARY KEY  (id)
      #   )
      #
      # == Unsaved objects and associations
      #
      # You can manipulate objects and associations before they are saved to the database, but
      # there is some special behavior you should be aware of, mostly involving the saving of
      # associated objects.
      #
      # You can set the <tt>:autosave</tt> option on a #has_one, #belongs_to,
      # #has_many, or #has_and_belongs_to_many association. Setting it
      # to +true+ will _always_ save the members, whereas setting it to +false+ will
      # _never_ save the members. More details about <tt>:autosave</tt> option is available at
      # AutosaveAssociation.
      #
      # === One-to-one associations
      #
      # * Assigning an object to a #has_one association automatically saves that object and
      #   the object being replaced (if there is one), in order to update their foreign
      #   keys - except if the parent object is unsaved (<tt>new_record? == true</tt>).
      # * If either of these saves fail (due to one of the objects being invalid), an
      #   ActiveRecord::RecordNotSaved exception is raised and the assignment is
      #   cancelled.
      # * If you wish to assign an object to a #has_one association without saving it,
      #   use the <tt>#build_association</tt> method (documented below). The object being
      #   replaced will still be saved to update its foreign key.
      # * Assigning an object to a #belongs_to association does not save the object, since
      #   the foreign key field belongs on the parent. It does not save the parent either.
      #
      # === Collections
      #
      # * Adding an object to a collection (#has_many or #has_and_belongs_to_many) automatically
      #   saves that object, except if the parent object (the owner of the collection) is not yet
      #   stored in the database.
      # * If saving any of the objects being added to a collection (via <tt>push</tt> or similar)
      #   fails, then <tt>push</tt> returns +false+.
      # * If saving fails while replacing the collection (via <tt>association=</tt>), an
      #   ActiveRecord::RecordNotSaved exception is raised and the assignment is
      #   cancelled.
      # * You can add an object to a collection without automatically saving it by using the
      #   <tt>collection.build</tt> method (documented below).
      # * All unsaved (<tt>new_record? == true</tt>) members of the collection are automatically
      #   saved when the parent is saved.
      #
      # == Customizing the query
      #
      # \Associations are built from <tt>Relation</tt> objects, and you can use the Relation syntax
      # to customize them. For example, to add a condition:
      #
      #   class Blog < ActiveRecord::Base
      #     has_many :published_posts, -> { where(published: true) }, class_name: 'Post'
      #   end
      #
      # Inside the <tt>-> { ... }</tt> block you can use all of the usual Relation methods.
      #
      # === Accessing the owner object
      #
      # Sometimes it is useful to have access to the owner object when building the query. The owner
      # is passed as a parameter to the block. For example, the following association would find all
      # events that occur on the user's birthday:
      #
      #   class User < ActiveRecord::Base
      #     has_many :birthday_events, ->(user) { where(starts_on: user.birthday) }, class_name: 'Event'
      #   end
      #
      # Note: Joining, eager loading and preloading of these associations is not possible.
      # These operations happen before instance creation and the scope will be called with a +nil+ argument.
      #
      # == Association callbacks
      #
      # Similar to the normal callbacks that hook into the life cycle of an Active Record object,
      # you can also define callbacks that get triggered when you add an object to or remove an
      # object from an association collection.
      #
      #   class Project
      #     has_and_belongs_to_many :developers, after_add: :evaluate_velocity
      #
      #     def evaluate_velocity(developer)
      #       ...
      #     end
      #   end
      #
      # It's possible to stack callbacks by passing them as an array. Example:
      #
      #   class Project
      #     has_and_belongs_to_many :developers,
      #                             after_add: [:evaluate_velocity, Proc.new { |p, d| p.shipping_date = Time.now}]
      #   end
      #
      # Possible callbacks are: +before_add+, +after_add+, +before_remove+ and +after_remove+.
      #
      # If any of the +before_add+ callbacks throw an exception, the object will not be
      # added to the collection.
      #
      # Similarly, if any of the +before_remove+ callbacks throw an exception, the object
      # will not be removed from the collection.
      #
      # == Association extensions
      #
      # The proxy objects that control the access to associations can be extended through anonymous
      # modules. This is especially beneficial for adding new finders, creators, and other
      # factory-type methods that are only used as part of this association.
      #
      #   class Account < ActiveRecord::Base
      #     has_many :people do
      #       def find_or_create_by_name(name)
      #         first_name, last_name = name.split(" ", 2)
      #         find_or_create_by(first_name: first_name, last_name: last_name)
      #       end
      #     end
      #   end
      #
      #   person = Account.first.people.find_or_create_by_name("David Heinemeier Hansson")
      #   person.first_name # => "David"
      #   person.last_name  # => "Heinemeier Hansson"
      #
      # If you need to share the same extensions between many associations, you can use a named
      # extension module.
      #
      #   module FindOrCreateByNameExtension
      #     def find_or_create_by_name(name)
      #       first_name, last_name = name.split(" ", 2)
      #       find_or_create_by(first_name: first_name, last_name: last_name)
      #     end
      #   end
      #
      #   class Account < ActiveRecord::Base
      #     has_many :people, -> { extending FindOrCreateByNameExtension }
      #   end
      #
      #   class Company < ActiveRecord::Base
      #     has_many :people, -> { extending FindOrCreateByNameExtension }
      #   end
      #
      # Some extensions can only be made to work with knowledge of the association's internals.
      # Extensions can access relevant state using the following methods (where +items+ is the
      # name of the association):
      #
      # * <tt>record.association(:items).owner</tt> - Returns the object the association is part of.
      # * <tt>record.association(:items).reflection</tt> - Returns the reflection object that describes the association.
      # * <tt>record.association(:items).target</tt> - Returns the associated object for #belongs_to and #has_one, or
      #   the collection of associated objects for #has_many and #has_and_belongs_to_many.
      #
      # However, inside the actual extension code, you will not have access to the <tt>record</tt> as
      # above. In this case, you can access <tt>proxy_association</tt>. For example,
      # <tt>record.association(:items)</tt> and <tt>record.items.proxy_association</tt> will return
      # the same object, allowing you to make calls like <tt>proxy_association.owner</tt> inside
      # association extensions.
      #
      # == Association Join Models
      #
      # Has Many associations can be configured with the <tt>:through</tt> option to use an
      # explicit join model to retrieve the data. This operates similarly to a
      # #has_and_belongs_to_many association. The advantage is that you're able to add validations,
      # callbacks, and extra attributes on the join model. Consider the following schema:
      #
      #   class Author < ActiveRecord::Base
      #     has_many :authorships
      #     has_many :books, through: :authorships
      #   end
      #
      #   class Authorship < ActiveRecord::Base
      #     belongs_to :author
      #     belongs_to :book
      #   end
      #
      #   @author = Author.first
      #   @author.authorships.collect { |a| a.book } # selects all books that the author's authorships belong to
      #   @author.books                              # selects all books by using the Authorship join model
      #
      # You can also go through a #has_many association on the join model:
      #
      #   class Firm < ActiveRecord::Base
      #     has_many   :clients
      #     has_many   :invoices, through: :clients
      #   end
      #
      #   class Client < ActiveRecord::Base
      #     belongs_to :firm
      #     has_many   :invoices
      #   end
      #
      #   class Invoice < ActiveRecord::Base
      #     belongs_to :client
      #   end
      #
      #   @firm = Firm.first
      #   @firm.clients.flat_map { |c| c.invoices } # select all invoices for all clients of the firm
      #   @firm.invoices                            # selects all invoices by going through the Client join model
      #
      # Similarly you can go through a #has_one association on the join model:
      #
      #   class Group < ActiveRecord::Base
      #     has_many   :users
      #     has_many   :avatars, through: :users
      #   end
      #
      #   class User < ActiveRecord::Base
      #     belongs_to :group
      #     has_one    :avatar
      #   end
      #
      #   class Avatar < ActiveRecord::Base
      #     belongs_to :user
      #   end
      #
      #   @group = Group.first
      #   @group.users.collect { |u| u.avatar }.compact # select all avatars for all users in the group
      #   @group.avatars                                # selects all avatars by going through the User join model.
      #
      # An important caveat with going through #has_one or #has_many associations on the
      # join model is that these associations are *read-only*. For example, the following
      # would not work following the previous example:
      #
      #   @group.avatars << Avatar.new   # this would work if User belonged_to Avatar rather than the other way around
      #   @group.avatars.delete(@group.avatars.last)  # so would this
      #
      # == Setting Inverses
      #
      # If you are using a #belongs_to on the join model, it is a good idea to set the
      # <tt>:inverse_of</tt> option on the #belongs_to, which will mean that the following example
      # works correctly (where <tt>tags</tt> is a #has_many <tt>:through</tt> association):
      #
      #   @post = Post.first
      #   @tag = @post.tags.build name: "ruby"
      #   @tag.save
      #
      # The last line ought to save the through record (a <tt>Tagging</tt>). This will only work if the
      # <tt>:inverse_of</tt> is set:
      #
      #   class Tagging < ActiveRecord::Base
      #     belongs_to :post
      #     belongs_to :tag, inverse_of: :taggings
      #   end
      #
      # If you do not set the <tt>:inverse_of</tt> record, the association will
      # do its best to match itself up with the correct inverse. Automatic
      # inverse detection only works on #has_many, #has_one, and
      # #belongs_to associations.
      #
      # Extra options on the associations, as defined in the
      # <tt>AssociationReflection::INVALID_AUTOMATIC_INVERSE_OPTIONS</tt>
      # constant, or a custom scope, will also prevent the association's inverse
      # from being found automatically.
      #
      # The automatic guessing of the inverse association uses a heuristic based
      # on the name of the class, so it may not work for all associations,
      # especially the ones with non-standard names.
      #
      # You can turn off the automatic detection of inverse associations by setting
      # the <tt>:inverse_of</tt> option to <tt>false</tt> like so:
      #
      #   class Tagging < ActiveRecord::Base
      #     belongs_to :tag, inverse_of: false
      #   end
      #
      # == Nested \Associations
      #
      # You can actually specify *any* association with the <tt>:through</tt> option, including an
      # association which has a <tt>:through</tt> option itself. For example:
      #
      #   class Author < ActiveRecord::Base
      #     has_many :posts
      #     has_many :comments, through: :posts
      #     has_many :commenters, through: :comments
      #   end
      #
      #   class Post < ActiveRecord::Base
      #     has_many :comments
      #   end
      #
      #   class Comment < ActiveRecord::Base
      #     belongs_to :commenter
      #   end
      #
      #   @author = Author.first
      #   @author.commenters # => People who commented on posts written by the author
      #
      # An equivalent way of setting up this association this would be:
      #
      #   class Author < ActiveRecord::Base
      #     has_many :posts
      #     has_many :commenters, through: :posts
      #   end
      #
      #   class Post < ActiveRecord::Base
      #     has_many :comments
      #     has_many :commenters, through: :comments
      #   end
      #
      #   class Comment < ActiveRecord::Base
      #     belongs_to :commenter
      #   end
      #
      # When using a nested association, you will not be able to modify the association because there
      # is not enough information to know what modification to make. For example, if you tried to
      # add a <tt>Commenter</tt> in the example above, there would be no way to tell how to set up the
      # intermediate <tt>Post</tt> and <tt>Comment</tt> objects.
      #
      # == Polymorphic \Associations
      #
      # Polymorphic associations on models are not restricted on what types of models they
      # can be associated with. Rather, they specify an interface that a #has_many association
      # must adhere to.
      #
      #   class Asset < ActiveRecord::Base
      #     belongs_to :attachable, polymorphic: true
      #   end
      #
      #   class Post < ActiveRecord::Base
      #     has_many :assets, as: :attachable         # The :as option specifies the polymorphic interface to use.
      #   end
      #
      #   @asset.attachable = @post
      #
      # This works by using a type column in addition to a foreign key to specify the associated
      # record. In the Asset example, you'd need an +attachable_id+ integer column and an
      # +attachable_type+ string column.
      #
      # Using polymorphic associations in combination with single table inheritance (STI) is
      # a little tricky. In order for the associations to work as expected, ensure that you
      # store the base model for the STI models in the type column of the polymorphic
      # association. To continue with the asset example above, suppose there are guest posts
      # and member posts that use the posts table for STI. In this case, there must be a +type+
      # column in the posts table.
      #
      # Note: The <tt>attachable_type=</tt> method is being called when assigning an +attachable+.
      # The +class_name+ of the +attachable+ is passed as a String.
      #
      #   class Asset < ActiveRecord::Base
      #     belongs_to :attachable, polymorphic: true
      #
      #     def attachable_type=(class_name)
      #        super(class_name.constantize.base_class.to_s)
      #     end
      #   end
      #
      #   class Post < ActiveRecord::Base
      #     # because we store "Post" in attachable_type now dependent: :destroy will work
      #     has_many :assets, as: :attachable, dependent: :destroy
      #   end
      #
      #   class GuestPost < Post
      #   end
      #
      #   class MemberPost < Post
      #   end
      #
      # == Caching
      #
      # All of the methods are built on a simple caching principle that will keep the result
      # of the last query around unless specifically instructed not to. The cache is even
      # shared across methods to make it even cheaper to use the macro-added methods without
      # worrying too much about performance at the first go.
      #
      #   project.milestones             # fetches milestones from the database
      #   project.milestones.size        # uses the milestone cache
      #   project.milestones.empty?      # uses the milestone cache
      #   project.milestones.reload.size # fetches milestones from the database
      #   project.milestones             # uses the milestone cache
      #
      # == Eager loading of associations
      #
      # Eager loading is a way to find objects of a certain class and a number of named associations.
      # It is one of the easiest ways to prevent the dreaded N+1 problem in which fetching 100
      # posts that each need to display their author triggers 101 database queries. Through the
      # use of eager loading, the number of queries will be reduced from 101 to 2.
      #
      #   class Post < ActiveRecord::Base
      #     belongs_to :author
      #     has_many   :comments
      #   end
      #
      # Consider the following loop using the class above:
      #
      #   Post.all.each do |post|
      #     puts "Post:            " + post.title
      #     puts "Written by:      " + post.author.name
      #     puts "Last comment on: " + post.comments.first.created_on
      #   end
      #
      # To iterate over these one hundred posts, we'll generate 201 database queries. Let's
      # first just optimize it for retrieving the author:
      #
      #   Post.includes(:author).each do |post|
      #
      # This references the name of the #belongs_to association that also used the <tt>:author</tt>
      # symbol. After loading the posts, +find+ will collect the +author_id+ from each one and load
      # all of the referenced authors with one query. Doing so will cut down the number of queries
      # from 201 to 102.
      #
      # We can improve upon the situation further by referencing both associations in the finder with:
      #
      #   Post.includes(:author, :comments).each do |post|
      #
      # This will load all comments with a single query. This reduces the total number of queries
      # to 3. In general, the number of queries will be 1 plus the number of associations
      # named (except if some of the associations are polymorphic #belongs_to - see below).
      #
      # To include a deep hierarchy of associations, use a hash:
      #
      #   Post.includes(:author, { comments: { author: :gravatar } }).each do |post|
      #
      # The above code will load all the comments and all of their associated
      # authors and gravatars. You can mix and match any combination of symbols,
      # arrays, and hashes to retrieve the associations you want to load.
      #
      # All of this power shouldn't fool you into thinking that you can pull out huge amounts
      # of data with no performance penalty just because you've reduced the number of queries.
      # The database still needs to send all the data to Active Record and it still needs to
      # be processed. So it's no catch-all for performance problems, but it's a great way to
      # cut down on the number of queries in a situation as the one described above.
      #
      # Since only one table is loaded at a time, conditions or orders cannot reference tables
      # other than the main one. If this is the case, Active Record falls back to the previously
      # used <tt>LEFT OUTER JOIN</tt> based strategy. For example:
      #
      #   Post.includes([:author, :comments]).where(['comments.approved = ?', true])
      #
      # This will result in a single SQL query with joins along the lines of:
      # <tt>LEFT OUTER JOIN comments ON comments.post_id = posts.id</tt> and
      # <tt>LEFT OUTER JOIN authors ON authors.id = posts.author_id</tt>. Note that using conditions
      # like this can have unintended consequences.
      # In the above example, posts with no approved comments are not returned at all because
      # the conditions apply to the SQL statement as a whole and not just to the association.
      #
      # You must disambiguate column references for this fallback to happen, for example
      # <tt>order: "author.name DESC"</tt> will work but <tt>order: "name DESC"</tt> will not.
      #
      # If you want to load all posts (including posts with no approved comments), then write
      # your own <tt>LEFT OUTER JOIN</tt> query using <tt>ON</tt>:
      #
      #   Post.joins("LEFT OUTER JOIN comments ON comments.post_id = posts.id AND comments.approved = '1'")
      #
      # In this case, it is usually more natural to include an association which has conditions defined on it:
      #
      #   class Post < ActiveRecord::Base
      #     has_many :approved_comments, -> { where(approved: true) }, class_name: 'Comment'
      #   end
      #
      #   Post.includes(:approved_comments)
      #
      # This will load posts and eager load the +approved_comments+ association, which contains
      # only those comments that have been approved.
      #
      # If you eager load an association with a specified <tt>:limit</tt> option, it will be ignored,
      # returning all the associated objects:
      #
      #   class Picture < ActiveRecord::Base
      #     has_many :most_recent_comments, -> { order('id DESC').limit(10) }, class_name: 'Comment'
      #   end
      #
      #   Picture.includes(:most_recent_comments).first.most_recent_comments # => returns all associated comments.
      #
      # Eager loading is supported with polymorphic associations.
      #
      #   class Address < ActiveRecord::Base
      #     belongs_to :addressable, polymorphic: true
      #   end
      #
      # A call that tries to eager load the addressable model
      #
      #   Address.includes(:addressable)
      #
      # This will execute one query to load the addresses and load the addressables with one
      # query per addressable type.
      # For example, if all the addressables are either of class Person or Company, then a total
      # of 3 queries will be executed. The list of addressable types to load is determined on
      # the back of the addresses loaded. This is not supported if Active Record has to fallback
      # to the previous implementation of eager loading and will raise ActiveRecord::EagerLoadPolymorphicError.
      # The reason is that the parent model's type is a column value so its corresponding table
      # name cannot be put in the +FROM+/+JOIN+ clauses of that query.
      #
      # == Table Aliasing
      #
      # Active Record uses table aliasing in the case that a table is referenced multiple times
      # in a join. If a table is referenced only once, the standard table name is used. The
      # second time, the table is aliased as <tt>#{reflection_name}_#{parent_table_name}</tt>.
      # Indexes are appended for any more successive uses of the table name.
      #
      #   Post.joins(:comments)
      #   # => SELECT ... FROM posts INNER JOIN comments ON ...
      #   Post.joins(:special_comments) # STI
      #   # => SELECT ... FROM posts INNER JOIN comments ON ... AND comments.type = 'SpecialComment'
      #   Post.joins(:comments, :special_comments) # special_comments is the reflection name, posts is the parent table name
      #   # => SELECT ... FROM posts INNER JOIN comments ON ... INNER JOIN comments special_comments_posts
      #
      # Acts as tree example:
      #
      #   TreeMixin.joins(:children)
      #   # => SELECT ... FROM mixins INNER JOIN mixins childrens_mixins ...
      #   TreeMixin.joins(children: :parent)
      #   # => SELECT ... FROM mixins INNER JOIN mixins childrens_mixins ...
      #                               INNER JOIN parents_mixins ...
      #   TreeMixin.joins(children: {parent: :children})
      #   # => SELECT ... FROM mixins INNER JOIN mixins childrens_mixins ...
      #                               INNER JOIN parents_mixins ...
      #                               INNER JOIN mixins childrens_mixins_2
      #
      # Has and Belongs to Many join tables use the same idea, but add a <tt>_join</tt> suffix:
      #
      #   Post.joins(:categories)
      #   # => SELECT ... FROM posts INNER JOIN categories_posts ... INNER JOIN categories ...
      #   Post.joins(categories: :posts)
      #   # => SELECT ... FROM posts INNER JOIN categories_posts ... INNER JOIN categories ...
      #                              INNER JOIN categories_posts posts_categories_join INNER JOIN posts posts_categories
      #   Post.joins(categories: {posts: :categories})
      #   # => SELECT ... FROM posts INNER JOIN categories_posts ... INNER JOIN categories ...
      #                              INNER JOIN categories_posts posts_categories_join INNER JOIN posts posts_categories
      #                              INNER JOIN categories_posts categories_posts_join INNER JOIN categories categories_posts_2
      #
      # If you wish to specify your own custom joins using ActiveRecord::QueryMethods#joins method, those table
      # names will take precedence over the eager associations:
      #
      #   Post.joins(:comments).joins("inner join comments ...")
      #   # => SELECT ... FROM posts INNER JOIN comments_posts ON ... INNER JOIN comments ...
      #   Post.joins(:comments, :special_comments).joins("inner join comments ...")
      #   # => SELECT ... FROM posts INNER JOIN comments comments_posts ON ...
      #                              INNER JOIN comments special_comments_posts ...
      #                              INNER JOIN comments ...
      #
      # Table aliases are automatically truncated according to the maximum length of table identifiers
      # according to the specific database.
      #
      # == Modules
      #
      # By default, associations will look for objects within the current module scope. Consider:
      #
      #   module MyApplication
      #     module Business
      #       class Firm < ActiveRecord::Base
      #         has_many :clients
      #       end
      #
      #       class Client < ActiveRecord::Base; end
      #     end
      #   end
      #
      # When <tt>Firm#clients</tt> is called, it will in turn call
      # <tt>MyApplication::Business::Client.find_all_by_firm_id(firm.id)</tt>.
      # If you want to associate with a class in another module scope, this can be done by
      # specifying the complete class name.
      #
      #   module MyApplication
      #     module Business
      #       class Firm < ActiveRecord::Base; end
      #     end
      #
      #     module Billing
      #       class Account < ActiveRecord::Base
      #         belongs_to :firm, class_name: "MyApplication::Business::Firm"
      #       end
      #     end
      #   end
      #
      # == Bi-directional associations
      #
      # When you specify an association, there is usually an association on the associated model
      # that specifies the same relationship in reverse. For example, with the following models:
      #
      #    class Dungeon < ActiveRecord::Base
      #      has_many :traps
      #      has_one :evil_wizard
      #    end
      #
      #    class Trap < ActiveRecord::Base
      #      belongs_to :dungeon
      #    end
      #
      #    class EvilWizard < ActiveRecord::Base
      #      belongs_to :dungeon
      #    end
      #
      # The +traps+ association on +Dungeon+ and the +dungeon+ association on +Trap+ are
      # the inverse of each other, and the inverse of the +dungeon+ association on +EvilWizard+
      # is the +evil_wizard+ association on +Dungeon+ (and vice-versa). By default,
      # Active Record can guess the inverse of the association based on the name
      # of the class. The result is the following:
      #
      #    d = Dungeon.first
      #    t = d.traps.first
      #    d.object_id == t.dungeon.object_id # => true
      #
      # The +Dungeon+ instances +d+ and <tt>t.dungeon</tt> in the above example refer to
      # the same in-memory instance since the association matches the name of the class.
      # The result would be the same if we added +:inverse_of+ to our model definitions:
      #
      #    class Dungeon < ActiveRecord::Base
      #      has_many :traps, inverse_of: :dungeon
      #      has_one :evil_wizard, inverse_of: :dungeon
      #    end
      #
      #    class Trap < ActiveRecord::Base
      #      belongs_to :dungeon, inverse_of: :traps
      #    end
      #
      #    class EvilWizard < ActiveRecord::Base
      #      belongs_to :dungeon, inverse_of: :evil_wizard
      #    end
      #
      # For more information, see the documentation for the +:inverse_of+ option.
      #
      # == Deleting from associations
      #
      # === Dependent associations
      #
      # #has_many, #has_one, and #belongs_to associations support the <tt>:dependent</tt> option.
      # This allows you to specify that associated records should be deleted when the owner is
      # deleted.
      #
      # For example:
      #
      #     class Author
      #       has_many :posts, dependent: :destroy
      #     end
      #     Author.find(1).destroy # => Will destroy all of the author's posts, too
      #
      # The <tt>:dependent</tt> option can have different values which specify how the deletion
      # is done. For more information, see the documentation for this option on the different
      # specific association types. When no option is given, the behavior is to do nothing
      # with the associated records when destroying a record.
      #
      # Note that <tt>:dependent</tt> is implemented using Rails' callback
      # system, which works by processing callbacks in order. Therefore, other
      # callbacks declared either before or after the <tt>:dependent</tt> option
      # can affect what it does.
      #
      # Note that <tt>:dependent</tt> option is ignored for #has_one <tt>:through</tt> associations.
      #
      # === Delete or destroy?
      #
      # #has_many and #has_and_belongs_to_many associations have the methods <tt>destroy</tt>,
      # <tt>delete</tt>, <tt>destroy_all</tt> and <tt>delete_all</tt>.
      #
      # For #has_and_belongs_to_many, <tt>delete</tt> and <tt>destroy</tt> are the same: they
      # cause the records in the join table to be removed.
      #
      # For #has_many, <tt>destroy</tt> and <tt>destroy_all</tt> will always call the <tt>destroy</tt> method of the
      # record(s) being removed so that callbacks are run. However <tt>delete</tt> and <tt>delete_all</tt> will either
      # do the deletion according to the strategy specified by the <tt>:dependent</tt> option, or
      # if no <tt>:dependent</tt> option is given, then it will follow the default strategy.
      # The default strategy is to do nothing (leave the foreign keys with the parent ids set), except for
      # #has_many <tt>:through</tt>, where the default strategy is <tt>delete_all</tt> (delete
      # the join records, without running their callbacks).
      #
      # There is also a <tt>clear</tt> method which is the same as <tt>delete_all</tt>, except that
      # it returns the association rather than the records which have been deleted.
      #
      # === What gets deleted?
      #
      # There is a potential pitfall here: #has_and_belongs_to_many and #has_many <tt>:through</tt>
      # associations have records in join tables, as well as the associated records. So when we
      # call one of these deletion methods, what exactly should be deleted?
      #
      # The answer is that it is assumed that deletion on an association is about removing the
      # <i>link</i> between the owner and the associated object(s), rather than necessarily the
      # associated objects themselves. So with #has_and_belongs_to_many and #has_many
      # <tt>:through</tt>, the join records will be deleted, but the associated records won't.
      #
      # This makes sense if you think about it: if you were to call <tt>post.tags.delete(Tag.find_by(name: 'food'))</tt>
      # you would want the 'food' tag to be unlinked from the post, rather than for the tag itself
      # to be removed from the database.
      #
      # However, there are examples where this strategy doesn't make sense. For example, suppose
      # a person has many projects, and each project has many tasks. If we deleted one of a person's
      # tasks, we would probably not want the project to be deleted. In this scenario, the delete method
      # won't actually work: it can only be used if the association on the join model is a
      # #belongs_to. In other situations you are expected to perform operations directly on
      # either the associated records or the <tt>:through</tt> association.
      #
      # With a regular #has_many there is no distinction between the "associated records"
      # and the "link", so there is only one choice for what gets deleted.
      #
      # With #has_and_belongs_to_many and #has_many <tt>:through</tt>, if you want to delete the
      # associated records themselves, you can always do something along the lines of
      # <tt>person.tasks.each(&:destroy)</tt>.
      #
      # == Type safety with ActiveRecord::AssociationTypeMismatch
      #
      # If you attempt to assign an object to an association that doesn't match the inferred
      # or specified <tt>:class_name</tt>, you'll get an ActiveRecord::AssociationTypeMismatch.
      #
      # == Options
      #
      # All of the association macros can be specialized through options. This makes cases
      # more complex than the simple and guessable ones possible.
      module ClassMethods
        # Specifies a one-to-many association. The following methods for retrieval and query of
        # collections of associated objects will be added:
        #
        # +collection+ is a placeholder for the symbol passed as the +name+ argument, so
        # <tt>has_many :clients</tt> would add among others <tt>clients.empty?</tt>.
        #
        # [collection]
        #   Returns a Relation of all the associated objects.
        #   An empty Relation is returned if none are found.
        # [collection<<(object, ...)]
        #   Adds one or more objects to the collection by setting their foreign keys to the collection's primary key.
        #   Note that this operation instantly fires update SQL without waiting for the save or update call on the
        #   parent object, unless the parent object is a new record.
        #   This will also run validations and callbacks of associated object(s).
        # [collection.delete(object, ...)]
        #   Removes one or more objects from the collection by setting their foreign keys to +NULL+.
        #   Objects will be in addition destroyed if they're associated with <tt>dependent: :destroy</tt>,
        #   and deleted if they're associated with <tt>dependent: :delete_all</tt>.
        #
        #   If the <tt>:through</tt> option is used, then the join records are deleted (rather than
        #   nullified) by default, but you can specify <tt>dependent: :destroy</tt> or
        #   <tt>dependent: :nullify</tt> to override this.
        # [collection.destroy(object, ...)]
        #   Removes one or more objects from the collection by running <tt>destroy</tt> on
        #   each record, regardless of any dependent option, ensuring callbacks are run.
        #
        #   If the <tt>:through</tt> option is used, then the join records are destroyed
        #   instead, not the objects themselves.
        # [collection=objects]
        #   Replaces the collections content by deleting and adding objects as appropriate. If the <tt>:through</tt>
        #   option is true callbacks in the join models are triggered except destroy callbacks, since deletion is
        #   direct by default. You can specify <tt>dependent: :destroy</tt> or
        #   <tt>dependent: :nullify</tt> to override this.
        # [collection_singular_ids]
        #   Returns an array of the associated objects' ids
        # [collection_singular_ids=ids]
        #   Replace the collection with the objects identified by the primary keys in +ids+. This
        #   method loads the models and calls <tt>collection=</tt>. See above.
        # [collection.clear]
        #   Removes every object from the collection. This destroys the associated objects if they
        #   are associated with <tt>dependent: :destroy</tt>, deletes them directly from the
        #   database if <tt>dependent: :delete_all</tt>, otherwise sets their foreign keys to +NULL+.
        #   If the <tt>:through</tt> option is true no destroy callbacks are invoked on the join models.
        #   Join models are directly deleted.
        # [collection.empty?]
        #   Returns +true+ if there are no associated objects.
        # [collection.size]
        #   Returns the number of associated objects.
        # [collection.find(...)]
        #   Finds an associated object according to the same rules as ActiveRecord::FinderMethods#find.
        # [collection.exists?(...)]
        #   Checks whether an associated object with the given conditions exists.
        #   Uses the same rules as ActiveRecord::FinderMethods#exists?.
        # [collection.build(attributes = {}, ...)]
        #   Returns one or more new objects of the collection type that have been instantiated
        #   with +attributes+ and linked to this object through a foreign key, but have not yet
        #   been saved.
        # [collection.create(attributes = {})]
        #   Returns a new object of the collection type that has been instantiated
        #   with +attributes+, linked to this object through a foreign key, and that has already
        #   been saved (if it passed the validation). *Note*: This only works if the base model
        #   already exists in the DB, not if it is a new (unsaved) record!
        # [collection.create!(attributes = {})]
        #   Does the same as <tt>collection.create</tt>, but raises ActiveRecord::RecordInvalid
        #   if the record is invalid.
        # [collection.reload]
        #   Returns a Relation of all of the associated objects, forcing a database read.
        #   An empty Relation is returned if none are found.
        #
        # === Example
        #
        # A <tt>Firm</tt> class declares <tt>has_many :clients</tt>, which will add:
        # * <tt>Firm#clients</tt> (similar to <tt>Client.where(firm_id: id)</tt>)
        # * <tt>Firm#clients<<</tt>
        # * <tt>Firm#clients.delete</tt>
        # * <tt>Firm#clients.destroy</tt>
        # * <tt>Firm#clients=</tt>
        # * <tt>Firm#client_ids</tt>
        # * <tt>Firm#client_ids=</tt>
        # * <tt>Firm#clients.clear</tt>
        # * <tt>Firm#clients.empty?</tt> (similar to <tt>firm.clients.size == 0</tt>)
        # * <tt>Firm#clients.size</tt> (similar to <tt>Client.count "firm_id = #{id}"</tt>)
        # * <tt>Firm#clients.find</tt> (similar to <tt>Client.where(firm_id: id).find(id)</tt>)
        # * <tt>Firm#clients.exists?(name: 'ACME')</tt> (similar to <tt>Client.exists?(name: 'ACME', firm_id: firm.id)</tt>)
        # * <tt>Firm#clients.build</tt> (similar to <tt>Client.new(firm_id: id)</tt>)
        # * <tt>Firm#clients.create</tt> (similar to <tt>c = Client.new(firm_id: id); c.save; c</tt>)
        # * <tt>Firm#clients.create!</tt> (similar to <tt>c = Client.new(firm_id: id); c.save!</tt>)
        # * <tt>Firm#clients.reload</tt>
        # The declaration can also include an +options+ hash to specialize the behavior of the association.
        #
        # === Scopes
        #
        # You can pass a second argument +scope+ as a callable (i.e. proc or
        # lambda) to retrieve a specific set of records or customize the generated
        # query when you access the associated collection.
        #
        # Scope examples:
        #   has_many :comments, -> { where(author_id: 1) }
        #   has_many :employees, -> { joins(:address) }
        #   has_many :posts, ->(blog) { where("max_post_length > ?", blog.max_post_length) }
        #
        # === Extensions
        #
        # The +extension+ argument allows you to pass a block into a has_many
        # association. This is useful for adding new finders, creators and other
        # factory-type methods to be used as part of the association.
        #
        # Extension examples:
        #   has_many :employees do
        #     def find_or_create_by_name(name)
        #       first_name, last_name = name.split(" ", 2)
        #       find_or_create_by(first_name: first_name, last_name: last_name)
        #     end
        #   end
        #
        # === Options
        # [:class_name]
        #   Specify the class name of the association. Use it only if that name can't be inferred
        #   from the association name. So <tt>has_many :products</tt> will by default be linked
        #   to the +Product+ class, but if the real class name is +SpecialProduct+, you'll have to
        #   specify it with this option.
        # [:foreign_key]
        #   Specify the foreign key used for the association. By default this is guessed to be the name
        #   of this class in lower-case and "_id" suffixed. So a Person class that makes a #has_many
        #   association will use "person_id" as the default <tt>:foreign_key</tt>.
        #
        #   If you are going to modify the association (rather than just read from it), then it is
        #   a good idea to set the <tt>:inverse_of</tt> option.
        # [:foreign_type]
        #   Specify the column used to store the associated object's type, if this is a polymorphic
        #   association. By default this is guessed to be the name of the polymorphic association
        #   specified on "as" option with a "_type" suffix. So a class that defines a
        #   <tt>has_many :tags, as: :taggable</tt> association will use "taggable_type" as the
        #   default <tt>:foreign_type</tt>.
        # [:primary_key]
        #   Specify the name of the column to use as the primary key for the association. By default this is +id+.
        # [:dependent]
        #   Controls what happens to the associated objects when
        #   their owner is destroyed. Note that these are implemented as
        #   callbacks, and Rails executes callbacks in order. Therefore, other
        #   similar callbacks may affect the <tt>:dependent</tt> behavior, and the
        #   <tt>:dependent</tt> behavior may affect other callbacks.
        #
        #   * <tt>:destroy</tt> causes all the associated objects to also be destroyed.
        #   * <tt>:delete_all</tt> causes all the associated objects to be deleted directly from the database (so callbacks will not be executed).
        #   * <tt>:nullify</tt> causes the foreign keys to be set to +NULL+. Polymorphic type will also be nullified
        #     on polymorphic associations. Callbacks are not executed.
        #   * <tt>:restrict_with_exception</tt> causes an <tt>ActiveRecord::DeleteRestrictionError</tt> exception to be raised if there are any associated records.
        #   * <tt>:restrict_with_error</tt> causes an error to be added to the owner if there are any associated objects.
        #
        #   If using with the <tt>:through</tt> option, the association on the join model must be
        #   a #belongs_to, and the records which get deleted are the join records, rather than
        #   the associated records.
        #
        #   If using <tt>dependent: :destroy</tt> on a scoped association, only the scoped objects are destroyed.
        #   For example, if a Post model defines
        #   <tt>has_many :comments, -> { where published: true }, dependent: :destroy</tt> and <tt>destroy</tt> is
        #   called on a post, only published comments are destroyed. This means that any unpublished comments in the
        #   database would still contain a foreign key pointing to the now deleted post.
        # [:counter_cache]
        #   This option can be used to configure a custom named <tt>:counter_cache.</tt> You only need this option,
        #   when you customized the name of your <tt>:counter_cache</tt> on the #belongs_to association.
        # [:as]
        #   Specifies a polymorphic interface (See #belongs_to).
        # [:through]
        #   Specifies an association through which to perform the query. This can be any other type
        #   of association, including other <tt>:through</tt> associations. Options for <tt>:class_name</tt>,
        #   <tt>:primary_key</tt> and <tt>:foreign_key</tt> are ignored, as the association uses the
        #   source reflection.
        #
        #   If the association on the join model is a #belongs_to, the collection can be modified
        #   and the records on the <tt>:through</tt> model will be automatically created and removed
        #   as appropriate. Otherwise, the collection is read-only, so you should manipulate the
        #   <tt>:through</tt> association directly.
        #
        #   If you are going to modify the association (rather than just read from it), then it is
        #   a good idea to set the <tt>:inverse_of</tt> option on the source association on the
        #   join model. This allows associated records to be built which will automatically create
        #   the appropriate join model records when they are saved. (See the 'Association Join Models'
        #   section above.)
        # [:source]
        #   Specifies the source association name used by #has_many <tt>:through</tt> queries.
        #   Only use it if the name cannot be inferred from the association.
        #   <tt>has_many :subscribers, through: :subscriptions</tt> will look for either <tt>:subscribers</tt> or
        #   <tt>:subscriber</tt> on Subscription, unless a <tt>:source</tt> is given.
        # [:source_type]
        #   Specifies type of the source association used by #has_many <tt>:through</tt> queries where the source
        #   association is a polymorphic #belongs_to.
        # [:validate]
        #   When set to +true+, validates new objects added to association when saving the parent object. +true+ by default.
        #   If you want to ensure associated objects are revalidated on every update, use +validates_associated+.
        # [:autosave]
        #   If true, always save the associated objects or destroy them if marked for destruction,
        #   when saving the parent object. If false, never save or destroy the associated objects.
        #   By default, only save associated objects that are new records. This option is implemented as a
        #   +before_save+ callback. Because callbacks are run in the order they are defined, associated objects
        #   may need to be explicitly saved in any user-defined +before_save+ callbacks.
        #
        #   Note that NestedAttributes::ClassMethods#accepts_nested_attributes_for sets
        #   <tt>:autosave</tt> to <tt>true</tt>.
        # [:inverse_of]
        #   Specifies the name of the #belongs_to association on the associated object
        #   that is the inverse of this #has_many association.
        #   See ActiveRecord::Associations::ClassMethods's overview on Bi-directional associations for more detail.
        # [:extend]
        #   Specifies a module or array of modules that will be extended into the association object returned.
        #   Useful for defining methods on associations, especially when they should be shared between multiple
        #   association objects.
        #
        # Option examples:
        #   has_many :comments, -> { order("posted_on") }
        #   has_many :comments, -> { includes(:author) }
        #   has_many :people, -> { where(deleted: false).order("name") }, class_name: "Person"
        #   has_many :tracks, -> { order("position") }, dependent: :destroy
        #   has_many :comments, dependent: :nullify
        #   has_many :tags, as: :taggable
        #   has_many :reports, -> { readonly }
        #   has_many :subscribers, through: :subscriptions, source: :user
        def has_many(name, scope = nil, **options, &extension)
          reflection = Builder::HasMany.build(self, name, scope, options, &extension)
          Reflection.add_reflection self, name, reflection
        end

        # Specifies a one-to-one association with another class. This method should only be used
        # if the other class contains the foreign key. If the current class contains the foreign key,
        # then you should use #belongs_to instead. See also ActiveRecord::Associations::ClassMethods's overview
        # on when to use #has_one and when to use #belongs_to.
        #
        # The following methods for retrieval and query of a single associated object will be added:
        #
        # +association+ is a placeholder for the symbol passed as the +name+ argument, so
        # <tt>has_one :manager</tt> would add among others <tt>manager.nil?</tt>.
        #
        # [association]
        #   Returns the associated object. +nil+ is returned if none is found.
        # [association=(associate)]
        #   Assigns the associate object, extracts the primary key, sets it as the foreign key,
        #   and saves the associate object. To avoid database inconsistencies, permanently deletes an existing
        #   associated object when assigning a new one, even if the new one isn't saved to database.
        # [build_association(attributes = {})]
        #   Returns a new object of the associated type that has been instantiated
        #   with +attributes+ and linked to this object through a foreign key, but has not
        #   yet been saved.
        # [create_association(attributes = {})]
        #   Returns a new object of the associated type that has been instantiated
        #   with +attributes+, linked to this object through a foreign key, and that
        #   has already been saved (if it passed the validation).
        # [create_association!(attributes = {})]
        #   Does the same as <tt>create_association</tt>, but raises ActiveRecord::RecordInvalid
        #   if the record is invalid.
        # [reload_association]
        #   Returns the associated object, forcing a database read.
        #
        # === Example
        #
        # An Account class declares <tt>has_one :beneficiary</tt>, which will add:
        # * <tt>Account#beneficiary</tt> (similar to <tt>Beneficiary.where(account_id: id).first</tt>)
        # * <tt>Account#beneficiary=(beneficiary)</tt> (similar to <tt>beneficiary.account_id = account.id; beneficiary.save</tt>)
        # * <tt>Account#build_beneficiary</tt> (similar to <tt>Beneficiary.new(account_id: id)</tt>)
        # * <tt>Account#create_beneficiary</tt> (similar to <tt>b = Beneficiary.new(account_id: id); b.save; b</tt>)
        # * <tt>Account#create_beneficiary!</tt> (similar to <tt>b = Beneficiary.new(account_id: id); b.save!; b</tt>)
        # * <tt>Account#reload_beneficiary</tt>
        #
        # === Scopes
        #
        # You can pass a second argument +scope+ as a callable (i.e. proc or
        # lambda) to retrieve a specific record or customize the generated query
        # when you access the associated object.
        #
        # Scope examples:
        #   has_one :author, -> { where(comment_id: 1) }
        #   has_one :employer, -> { joins(:company) }
        #   has_one :latest_post, ->(blog) { where("created_at > ?", blog.enabled_at) }
        #
        # === Options
        #
        # The declaration can also include an +options+ hash to specialize the behavior of the association.
        #
        # Options are:
        # [:class_name]
        #   Specify the class name of the association. Use it only if that name can't be inferred
        #   from the association name. So <tt>has_one :manager</tt> will by default be linked to the Manager class, but
        #   if the real class name is Person, you'll have to specify it with this option.
        # [:dependent]
        #   Controls what happens to the associated object when
        #   its owner is destroyed:
        #
        #   * <tt>:destroy</tt> causes the associated object to also be destroyed
        #   * <tt>:delete</tt> causes the associated object to be deleted directly from the database (so callbacks will not execute)
        #   * <tt>:nullify</tt> causes the foreign key to be set to +NULL+. Polymorphic type column is also nullified
        #     on polymorphic associations. Callbacks are not executed.
        #   * <tt>:restrict_with_exception</tt> causes an <tt>ActiveRecord::DeleteRestrictionError</tt> exception to be raised if there is an associated record
        #   * <tt>:restrict_with_error</tt> causes an error to be added to the owner if there is an associated object
        #
        #   Note that <tt>:dependent</tt> option is ignored when using <tt>:through</tt> option.
        # [:foreign_key]
        #   Specify the foreign key used for the association. By default this is guessed to be the name
        #   of this class in lower-case and "_id" suffixed. So a Person class that makes a #has_one association
        #   will use "person_id" as the default <tt>:foreign_key</tt>.
        #
        #   If you are going to modify the association (rather than just read from it), then it is
        #   a good idea to set the <tt>:inverse_of</tt> option.
        # [:foreign_type]
        #   Specify the column used to store the associated object's type, if this is a polymorphic
        #   association. By default this is guessed to be the name of the polymorphic association
        #   specified on "as" option with a "_type" suffix. So a class that defines a
        #   <tt>has_one :tag, as: :taggable</tt> association will use "taggable_type" as the
        #   default <tt>:foreign_type</tt>.
        # [:primary_key]
        #   Specify the method that returns the primary key used for the association. By default this is +id+.
        # [:as]
        #   Specifies a polymorphic interface (See #belongs_to).
        # [:through]
        #   Specifies a Join Model through which to perform the query. Options for <tt>:class_name</tt>,
        #   <tt>:primary_key</tt>, and <tt>:foreign_key</tt> are ignored, as the association uses the
        #   source reflection. You can only use a <tt>:through</tt> query through a #has_one
        #   or #belongs_to association on the join model.
        #
        #   If you are going to modify the association (rather than just read from it), then it is
        #   a good idea to set the <tt>:inverse_of</tt> option.
        # [:source]
        #   Specifies the source association name used by #has_one <tt>:through</tt> queries.
        #   Only use it if the name cannot be inferred from the association.
        #   <tt>has_one :favorite, through: :favorites</tt> will look for a
        #   <tt>:favorite</tt> on Favorite, unless a <tt>:source</tt> is given.
        # [:source_type]
        #   Specifies type of the source association used by #has_one <tt>:through</tt> queries where the source
        #   association is a polymorphic #belongs_to.
        # [:validate]
        #   When set to +true+, validates new objects added to association when saving the parent object. +false+ by default.
        #   If you want to ensure associated objects are revalidated on every update, use +validates_associated+.
        # [:autosave]
        #   If true, always save the associated object or destroy it if marked for destruction,
        #   when saving the parent object. If false, never save or destroy the associated object.
        #   By default, only save the associated object if it's a new record.
        #
        #   Note that NestedAttributes::ClassMethods#accepts_nested_attributes_for sets
        #   <tt>:autosave</tt> to <tt>true</tt>.
        # [:inverse_of]
        #   Specifies the name of the #belongs_to association on the associated object
        #   that is the inverse of this #has_one association.
        #   See ActiveRecord::Associations::ClassMethods's overview on Bi-directional associations for more detail.
        # [:required]
        #   When set to +true+, the association will also have its presence validated.
        #   This will validate the association itself, not the id. You can use
        #   +:inverse_of+ to avoid an extra query during validation.
        #
        # Option examples:
        #   has_one :credit_card, dependent: :destroy  # destroys the associated credit card
        #   has_one :credit_card, dependent: :nullify  # updates the associated records foreign
        #                                                 # key value to NULL rather than destroying it
        #   has_one :last_comment, -> { order('posted_on') }, class_name: "Comment"
        #   has_one :project_manager, -> { where(role: 'project_manager') }, class_name: "Person"
        #   has_one :attachment, as: :attachable
        #   has_one :boss, -> { readonly }
        #   has_one :club, through: :membership
        #   has_one :primary_address, -> { where(primary: true) }, through: :addressables, source: :addressable
        #   has_one :credit_card, required: true
        def has_one(name, scope = nil, **options)
          reflection = Builder::HasOne.build(self, name, scope, options)
          Reflection.add_reflection self, name, reflection
        end

        # Specifies a one-to-one association with another class. This method should only be used
        # if this class contains the foreign key. If the other class contains the foreign key,
        # then you should use #has_one instead. See also ActiveRecord::Associations::ClassMethods's overview
        # on when to use #has_one and when to use #belongs_to.
        #
        # Methods will be added for retrieval and query for a single associated object, for which
        # this object holds an id:
        #
        # +association+ is a placeholder for the symbol passed as the +name+ argument, so
        # <tt>belongs_to :author</tt> would add among others <tt>author.nil?</tt>.
        #
        # [association]
        #   Returns the associated object. +nil+ is returned if none is found.
        # [association=(associate)]
        #   Assigns the associate object, extracts the primary key, and sets it as the foreign key.
        #   No modification or deletion of existing records takes place.
        # [build_association(attributes = {})]
        #   Returns a new object of the associated type that has been instantiated
        #   with +attributes+ and linked to this object through a foreign key, but has not yet been saved.
        # [create_association(attributes = {})]
        #   Returns a new object of the associated type that has been instantiated
        #   with +attributes+, linked to this object through a foreign key, and that
        #   has already been saved (if it passed the validation).
        # [create_association!(attributes = {})]
        #   Does the same as <tt>create_association</tt>, but raises ActiveRecord::RecordInvalid
        #   if the record is invalid.
        # [reload_association]
        #   Returns the associated object, forcing a database read.
        #
        # === Example
        #
        # A Post class declares <tt>belongs_to :author</tt>, which will add:
        # * <tt>Post#author</tt> (similar to <tt>Author.find(author_id)</tt>)
        # * <tt>Post#author=(author)</tt> (similar to <tt>post.author_id = author.id</tt>)
        # * <tt>Post#build_author</tt> (similar to <tt>post.author = Author.new</tt>)
        # * <tt>Post#create_author</tt> (similar to <tt>post.author = Author.new; post.author.save; post.author</tt>)
        # * <tt>Post#create_author!</tt> (similar to <tt>post.author = Author.new; post.author.save!; post.author</tt>)
        # * <tt>Post#reload_author</tt>
        # The declaration can also include an +options+ hash to specialize the behavior of the association.
        #
        # === Scopes
        #
        # You can pass a second argument +scope+ as a callable (i.e. proc or
        # lambda) to retrieve a specific record or customize the generated query
        # when you access the associated object.
        #
        # Scope examples:
        #   belongs_to :firm, -> { where(id: 2) }
        #   belongs_to :user, -> { joins(:friends) }
        #   belongs_to :level, ->(game) { where("game_level > ?", game.current_level) }
        #
        # === Options
        #
        # [:class_name]
        #   Specify the class name of the association. Use it only if that name can't be inferred
        #   from the association name. So <tt>belongs_to :author</tt> will by default be linked to the Author class, but
        #   if the real class name is Person, you'll have to specify it with this option.
        # [:foreign_key]
        #   Specify the foreign key used for the association. By default this is guessed to be the name
        #   of the association with an "_id" suffix. So a class that defines a <tt>belongs_to :person</tt>
        #   association will use "person_id" as the default <tt>:foreign_key</tt>. Similarly,
        #   <tt>belongs_to :favorite_person, class_name: "Person"</tt> will use a foreign key
        #   of "favorite_person_id".
        #
        #   If you are going to modify the association (rather than just read from it), then it is
        #   a good idea to set the <tt>:inverse_of</tt> option.
        # [:foreign_type]
        #   Specify the column used to store the associated object's type, if this is a polymorphic
        #   association. By default this is guessed to be the name of the association with a "_type"
        #   suffix. So a class that defines a <tt>belongs_to :taggable, polymorphic: true</tt>
        #   association will use "taggable_type" as the default <tt>:foreign_type</tt>.
        # [:primary_key]
        #   Specify the method that returns the primary key of associated object used for the association.
        #   By default this is +id+.
        # [:dependent]
        #   If set to <tt>:destroy</tt>, the associated object is destroyed when this object is. If set to
        #   <tt>:delete</tt>, the associated object is deleted *without* calling its destroy method.
        #   This option should not be specified when #belongs_to is used in conjunction with
        #   a #has_many relationship on another class because of the potential to leave
        #   orphaned records behind.
        # [:counter_cache]
        #   Caches the number of belonging objects on the associate class through the use of CounterCache::ClassMethods#increment_counter
        #   and CounterCache::ClassMethods#decrement_counter. The counter cache is incremented when an object of this
        #   class is created and decremented when it's destroyed. This requires that a column
        #   named <tt>#{table_name}_count</tt> (such as +comments_count+ for a belonging Comment class)
        #   is used on the associate class (such as a Post class) - that is the migration for
        #   <tt>#{table_name}_count</tt> is created on the associate class (such that <tt>Post.comments_count</tt> will
        #   return the count cached, see note below). You can also specify a custom counter
        #   cache column by providing a column name instead of a +true+/+false+ value to this
        #   option (e.g., <tt>counter_cache: :my_custom_counter</tt>.)
        #   Note: Specifying a counter cache will add it to that model's list of readonly attributes
        #   using +attr_readonly+.
        # [:polymorphic]
        #   Specify this association is a polymorphic association by passing +true+.
        #   Note: If you've enabled the counter cache, then you may want to add the counter cache attribute
        #   to the +attr_readonly+ list in the associated classes (e.g. <tt>class Post; attr_readonly :comments_count; end</tt>).
        # [:validate]
        #   When set to +true+, validates new objects added to association when saving the parent object. +false+ by default.
        #   If you want to ensure associated objects are revalidated on every update, use +validates_associated+.
        # [:autosave]
        #   If true, always save the associated object or destroy it if marked for destruction, when
        #   saving the parent object.
        #   If false, never save or destroy the associated object.
        #   By default, only save the associated object if it's a new record.
        #
        #   Note that NestedAttributes::ClassMethods#accepts_nested_attributes_for
        #   sets <tt>:autosave</tt> to <tt>true</tt>.
        # [:touch]
        #   If true, the associated object will be touched (the updated_at/on attributes set to current time)
        #   when this record is either saved or destroyed. If you specify a symbol, that attribute
        #   will be updated with the current time in addition to the updated_at/on attribute.
        #   Please note that with touching no validation is performed and only the +after_touch+,
        #   +after_commit+ and +after_rollback+ callbacks are executed.
        # [:inverse_of]
        #   Specifies the name of the #has_one or #has_many association on the associated
        #   object that is the inverse of this #belongs_to association.
        #   See ActiveRecord::Associations::ClassMethods's overview on Bi-directional associations for more detail.
        # [:optional]
        #   When set to +true+, the association will not have its presence validated.
        # [:required]
        #   When set to +true+, the association will also have its presence validated.
        #   This will validate the association itself, not the id. You can use
        #   +:inverse_of+ to avoid an extra query during validation.
        #   NOTE: <tt>required</tt> is set to <tt>true</tt> by default and is deprecated. If
        #   you don't want to have association presence validated, use <tt>optional: true</tt>.
        # [:default]
        #   Provide a callable (i.e. proc or lambda) to specify that the association should
        #   be initialized with a particular record before validation.
        #
        # Option examples:
        #   belongs_to :firm, foreign_key: "client_of"
        #   belongs_to :person, primary_key: "name", foreign_key: "person_name"
        #   belongs_to :author, class_name: "Person", foreign_key: "author_id"
        #   belongs_to :valid_coupon, ->(o) { where "discounts > ?", o.payments_count },
        #                             class_name: "Coupon", foreign_key: "coupon_id"
        #   belongs_to :attachable, polymorphic: true
        #   belongs_to :project, -> { readonly }
        #   belongs_to :post, counter_cache: true
        #   belongs_to :comment, touch: true
        #   belongs_to :company, touch: :employees_last_updated_at
        #   belongs_to :user, optional: true
        #   belongs_to :account, default: -> { company.account }
        def belongs_to(name, scope = nil, **options)
          reflection = Builder::BelongsTo.build(self, name, scope, options)
          Reflection.add_reflection self, name, reflection
        end

        # Specifies a many-to-many relationship with another class. This associates two classes via an
        # intermediate join table. Unless the join table is explicitly specified as an option, it is
        # guessed using the lexical order of the class names. So a join between Developer and Project
        # will give the default join table name of "developers_projects" because "D" precedes "P" alphabetically.
        # Note that this precedence is calculated using the <tt><</tt> operator for String. This
        # means that if the strings are of different lengths, and the strings are equal when compared
        # up to the shortest length, then the longer string is considered of higher
        # lexical precedence than the shorter one. For example, one would expect the tables "paper_boxes" and "papers"
        # to generate a join table name of "papers_paper_boxes" because of the length of the name "paper_boxes",
        # but it in fact generates a join table name of "paper_boxes_papers". Be aware of this caveat, and use the
        # custom <tt>:join_table</tt> option if you need to.
        # If your tables share a common prefix, it will only appear once at the beginning. For example,
        # the tables "catalog_categories" and "catalog_products" generate a join table name of "catalog_categories_products".
        #
        # The join table should not have a primary key or a model associated with it. You must manually generate the
        # join table with a migration such as this:
        #
        #   class CreateDevelopersProjectsJoinTable < ActiveRecord::Migration[5.0]
        #     def change
        #       create_join_table :developers, :projects
        #     end
        #   end
        #
        # It's also a good idea to add indexes to each of those columns to speed up the joins process.
        # However, in MySQL it is advised to add a compound index for both of the columns as MySQL only
        # uses one index per table during the lookup.
        #
        # Adds the following methods for retrieval and query:
        #
        # +collection+ is a placeholder for the symbol passed as the +name+ argument, so
        # <tt>has_and_belongs_to_many :categories</tt> would add among others <tt>categories.empty?</tt>.
        #
        # [collection]
        #   Returns a Relation of all the associated objects.
        #   An empty Relation is returned if none are found.
        # [collection<<(object, ...)]
        #   Adds one or more objects to the collection by creating associations in the join table
        #   (<tt>collection.push</tt> and <tt>collection.concat</tt> are aliases to this method).
        #   Note that this operation instantly fires update SQL without waiting for the save or update call on the
        #   parent object, unless the parent object is a new record.
        # [collection.delete(object, ...)]
        #   Removes one or more objects from the collection by removing their associations from the join table.
        #   This does not destroy the objects.
        # [collection.destroy(object, ...)]
        #   Removes one or more objects from the collection by running destroy on each association in the join table, overriding any dependent option.
        #   This does not destroy the objects.
        # [collection=objects]
        #   Replaces the collection's content by deleting and adding objects as appropriate.
        # [collection_singular_ids]
        #   Returns an array of the associated objects' ids.
        # [collection_singular_ids=ids]
        #   Replace the collection by the objects identified by the primary keys in +ids+.
        # [collection.clear]
        #   Removes every object from the collection. This does not destroy the objects.
        # [collection.empty?]
        #   Returns +true+ if there are no associated objects.
        # [collection.size]
        #   Returns the number of associated objects.
        # [collection.find(id)]
        #   Finds an associated object responding to the +id+ and that
        #   meets the condition that it has to be associated with this object.
        #   Uses the same rules as ActiveRecord::FinderMethods#find.
        # [collection.exists?(...)]
        #   Checks whether an associated object with the given conditions exists.
        #   Uses the same rules as ActiveRecord::FinderMethods#exists?.
        # [collection.build(attributes = {})]
        #   Returns a new object of the collection type that has been instantiated
        #   with +attributes+ and linked to this object through the join table, but has not yet been saved.
        # [collection.create(attributes = {})]
        #   Returns a new object of the collection type that has been instantiated
        #   with +attributes+, linked to this object through the join table, and that has already been
        #   saved (if it passed the validation).
        # [collection.reload]
        #   Returns a Relation of all of the associated objects, forcing a database read.
        #   An empty Relation is returned if none are found.
        #
        # === Example
        #
        # A Developer class declares <tt>has_and_belongs_to_many :projects</tt>, which will add:
        # * <tt>Developer#projects</tt>
        # * <tt>Developer#projects<<</tt>
        # * <tt>Developer#projects.delete</tt>
        # * <tt>Developer#projects.destroy</tt>
        # * <tt>Developer#projects=</tt>
        # * <tt>Developer#project_ids</tt>
        # * <tt>Developer#project_ids=</tt>
        # * <tt>Developer#projects.clear</tt>
        # * <tt>Developer#projects.empty?</tt>
        # * <tt>Developer#projects.size</tt>
        # * <tt>Developer#projects.find(id)</tt>
        # * <tt>Developer#projects.exists?(...)</tt>
        # * <tt>Developer#projects.build</tt> (similar to <tt>Project.new(developer_id: id)</tt>)
        # * <tt>Developer#projects.create</tt> (similar to <tt>c = Project.new(developer_id: id); c.save; c</tt>)
        # * <tt>Developer#projects.reload</tt>
        # The declaration may include an +options+ hash to specialize the behavior of the association.
        #
        # === Scopes
        #
        # You can pass a second argument +scope+ as a callable (i.e. proc or
        # lambda) to retrieve a specific set of records or customize the generated
        # query when you access the associated collection.
        #
        # Scope examples:
        #   has_and_belongs_to_many :projects, -> { includes(:milestones, :manager) }
        #   has_and_belongs_to_many :categories, ->(post) {
        #     where("default_category = ?", post.default_category)
        #   }
        #
        # === Extensions
        #
        # The +extension+ argument allows you to pass a block into a
        # has_and_belongs_to_many association. This is useful for adding new
        # finders, creators and other factory-type methods to be used as part of
        # the association.
        #
        # Extension examples:
        #   has_and_belongs_to_many :contractors do
        #     def find_or_create_by_name(name)
        #       first_name, last_name = name.split(" ", 2)
        #       find_or_create_by(first_name: first_name, last_name: last_name)
        #     end
        #   end
        #
        # === Options
        #
        # [:class_name]
        #   Specify the class name of the association. Use it only if that name can't be inferred
        #   from the association name. So <tt>has_and_belongs_to_many :projects</tt> will by default be linked to the
        #   Project class, but if the real class name is SuperProject, you'll have to specify it with this option.
        # [:join_table]
        #   Specify the name of the join table if the default based on lexical order isn't what you want.
        #   <b>WARNING:</b> If you're overwriting the table name of either class, the +table_name+ method
        #   MUST be declared underneath any #has_and_belongs_to_many declaration in order to work.
        # [:foreign_key]
        #   Specify the foreign key used for the association. By default this is guessed to be the name
        #   of this class in lower-case and "_id" suffixed. So a Person class that makes
        #   a #has_and_belongs_to_many association to Project will use "person_id" as the
        #   default <tt>:foreign_key</tt>.
        #
        #   If you are going to modify the association (rather than just read from it), then it is
        #   a good idea to set the <tt>:inverse_of</tt> option.
        # [:association_foreign_key]
        #   Specify the foreign key used for the association on the receiving side of the association.
        #   By default this is guessed to be the name of the associated class in lower-case and "_id" suffixed.
        #   So if a Person class makes a #has_and_belongs_to_many association to Project,
        #   the association will use "project_id" as the default <tt>:association_foreign_key</tt>.
        # [:validate]
        #   When set to +true+, validates new objects added to association when saving the parent object. +true+ by default.
        #   If you want to ensure associated objects are revalidated on every update, use +validates_associated+.
        # [:autosave]
        #   If true, always save the associated objects or destroy them if marked for destruction, when
        #   saving the parent object.
        #   If false, never save or destroy the associated objects.
        #   By default, only save associated objects that are new records.
        #
        #   Note that NestedAttributes::ClassMethods#accepts_nested_attributes_for sets
        #   <tt>:autosave</tt> to <tt>true</tt>.
        #
        # Option examples:
        #   has_and_belongs_to_many :projects
        #   has_and_belongs_to_many :projects, -> { includes(:milestones, :manager) }
        #   has_and_belongs_to_many :nations, class_name: "Country"
        #   has_and_belongs_to_many :categories, join_table: "prods_cats"
        #   has_and_belongs_to_many :categories, -> { readonly }
        def has_and_belongs_to_many(name, scope = nil, **options, &extension)
          habtm_reflection = ActiveRecord::Reflection::HasAndBelongsToManyReflection.new(name, scope, options, self)

          builder = Builder::HasAndBelongsToMany.new name, self, options

          join_model = builder.through_model

          const_set join_model.name, join_model
          private_constant join_model.name

          middle_reflection = builder.middle_reflection join_model

          Builder::HasMany.define_callbacks self, middle_reflection
          Reflection.add_reflection self, middle_reflection.name, middle_reflection
          middle_reflection.parent_reflection = habtm_reflection

          include Module.new {
            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def destroy_associations
                association(:#{middle_reflection.name}).delete_all(:delete_all)
                association(:#{name}).reset
                super
              end
            RUBY
          }

          hm_options = {}
          hm_options[:through] = middle_reflection.name
          hm_options[:source] = join_model.right_reflection.name

          [:before_add, :after_add, :before_remove, :after_remove, :autosave, :validate, :join_table, :class_name, :extend].each do |k|
            hm_options[k] = options[k] if options.key? k
          end

          has_many name, scope, hm_options, &extension
          _reflections[name.to_s].parent_reflection = habtm_reflection
        end
      end
  end
end
