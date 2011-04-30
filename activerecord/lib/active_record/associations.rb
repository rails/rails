require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string/conversions'
require 'active_support/core_ext/module/remove_method'

module ActiveRecord
  class InverseOfAssociationNotFoundError < ActiveRecordError #:nodoc:
    def initialize(reflection, associated_class = nil)
      super("Could not find the inverse association for #{reflection.name} (#{reflection.options[:inverse_of].inspect} in #{associated_class.nil? ? reflection.class_name : associated_class.name})")
    end
  end

  class HasManyThroughAssociationNotFoundError < ActiveRecordError #:nodoc:
    def initialize(owner_class_name, reflection)
      super("Could not find the association #{reflection.options[:through].inspect} in model #{owner_class_name}")
    end
  end

  class HasManyThroughAssociationPolymorphicError < ActiveRecordError #:nodoc:
    def initialize(owner_class_name, reflection, source_reflection)
      super("Cannot have a has_many :through association '#{owner_class_name}##{reflection.name}' on the polymorphic object '#{source_reflection.class_name}##{source_reflection.name}'.")
    end
  end

  class HasManyThroughAssociationPointlessSourceTypeError < ActiveRecordError #:nodoc:
    def initialize(owner_class_name, reflection, source_reflection)
      super("Cannot have a has_many :through association '#{owner_class_name}##{reflection.name}' with a :source_type option if the '#{reflection.through_reflection.class_name}##{source_reflection.name}' is not polymorphic.  Try removing :source_type on your association.")
    end
  end

  class HasManyThroughSourceAssociationNotFoundError < ActiveRecordError #:nodoc:
    def initialize(reflection)
      through_reflection      = reflection.through_reflection
      source_reflection_names = reflection.source_reflection_names
      source_associations     = reflection.through_reflection.klass.reflect_on_all_associations.collect { |a| a.name.inspect }
      super("Could not find the source association(s) #{source_reflection_names.collect{ |a| a.inspect }.to_sentence(:two_words_connector => ' or ', :last_word_connector => ', or ', :locale => :en)} in model #{through_reflection.klass}.  Try 'has_many #{reflection.name.inspect}, :through => #{through_reflection.name.inspect}, :source => <name>'.  Is it one of #{source_associations.to_sentence(:two_words_connector => ' or ', :last_word_connector => ', or ', :locale => :en)}?")
    end
  end

  class HasManyThroughSourceAssociationMacroError < ActiveRecordError #:nodoc:
    def initialize(reflection)
      through_reflection = reflection.through_reflection
      source_reflection  = reflection.source_reflection
      super("Invalid source reflection macro :#{source_reflection.macro}#{" :through" if source_reflection.options[:through]} for has_many #{reflection.name.inspect}, :through => #{through_reflection.name.inspect}.  Use :source to specify the source reflection.")
    end
  end

  class HasManyThroughCantAssociateThroughHasOneOrManyReflection < ActiveRecordError #:nodoc:
    def initialize(owner, reflection)
      super("Cannot modify association '#{owner.class.name}##{reflection.name}' because the source reflection class '#{reflection.source_reflection.class_name}' is associated to '#{reflection.through_reflection.class_name}' via :#{reflection.source_reflection.macro}.")
    end
  end

  class HasManyThroughCantAssociateNewRecords < ActiveRecordError #:nodoc:
    def initialize(owner, reflection)
      super("Cannot associate new records through '#{owner.class.name}##{reflection.name}' on '#{reflection.source_reflection.class_name rescue nil}##{reflection.source_reflection.name rescue nil}'. Both records must have an id in order to create the has_many :through record associating them.")
    end
  end

  class HasManyThroughCantDissociateNewRecords < ActiveRecordError #:nodoc:
    def initialize(owner, reflection)
      super("Cannot dissociate new records through '#{owner.class.name}##{reflection.name}' on '#{reflection.source_reflection.class_name rescue nil}##{reflection.source_reflection.name rescue nil}'. Both records must have an id in order to delete the has_many :through record associating them.")
    end
  end

  class HasAndBelongsToManyAssociationWithPrimaryKeyError < ActiveRecordError #:nodoc:
    def initialize(reflection)
      super("Primary key is not allowed in a has_and_belongs_to_many join table (#{reflection.options[:join_table]}).")
    end
  end

  class HasAndBelongsToManyAssociationForeignKeyNeeded < ActiveRecordError #:nodoc:
    def initialize(reflection)
      super("Cannot create self referential has_and_belongs_to_many association on '#{reflection.class_name rescue nil}##{reflection.name rescue nil}'. :association_foreign_key cannot be the same as the :foreign_key.")
    end
  end

  class EagerLoadPolymorphicError < ActiveRecordError #:nodoc:
    def initialize(reflection)
      super("Can not eagerly load the polymorphic association #{reflection.name.inspect}")
    end
  end

  class ReadOnlyAssociation < ActiveRecordError #:nodoc:
    def initialize(reflection)
      super("Can not add to a has_many :through association.  Try adding to #{reflection.through_reflection.name.inspect}.")
    end
  end

  # This error is raised when trying to destroy a parent instance in N:1 or 1:1 associations
  # (has_many, has_one) when there is at least 1 child associated instance.
  # ex: if @project.tasks.size > 0, DeleteRestrictionError will be raised when trying to destroy @project
  class DeleteRestrictionError < ActiveRecordError #:nodoc:
    def initialize(reflection)
      super("Cannot delete record because of dependent #{reflection.name}")
    end
  end

  # See ActiveRecord::Associations::ClassMethods for documentation.
  module Associations # :nodoc:
    extend ActiveSupport::Concern

    # These classes will be loaded when associations are created.
    # So there is no need to eager load them.
    autoload :AssociationCollection, 'active_record/associations/association_collection'
    autoload :AssociationProxy, 'active_record/associations/association_proxy'
    autoload :BelongsToAssociation, 'active_record/associations/belongs_to_association'
    autoload :BelongsToPolymorphicAssociation, 'active_record/associations/belongs_to_polymorphic_association'
    autoload :HasAndBelongsToManyAssociation, 'active_record/associations/has_and_belongs_to_many_association'
    autoload :HasManyAssociation, 'active_record/associations/has_many_association'
    autoload :HasManyThroughAssociation, 'active_record/associations/has_many_through_association'
    autoload :HasOneAssociation, 'active_record/associations/has_one_association'
    autoload :HasOneThroughAssociation, 'active_record/associations/has_one_through_association'

    # Clears out the association cache.
    def clear_association_cache #:nodoc:
      self.class.reflect_on_all_associations.to_a.each do |assoc|
        instance_variable_set "@#{assoc.name}", nil
      end unless self.new_record?
    end

    private
      # Returns the specified association instance if it responds to :loaded?, nil otherwise.
      def association_instance_get(name)
        ivar = "@#{name}"
        if instance_variable_defined?(ivar)
          association = instance_variable_get(ivar)
          association if association.respond_to?(:loaded?)
        end
      end

      # Set the specified association instance.
      def association_instance_set(name, association)
        instance_variable_set("@#{name}", association)
      end

    # Associations are a set of macro-like class methods for tying objects together through
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
    # * <tt>Project#portfolio, Project#portfolio=(portfolio), Project#portfolio.nil?</tt>
    # * <tt>Project#project_manager, Project#project_manager=(project_manager), Project#project_manager.nil?,</tt>
    # * <tt>Project#milestones.empty?, Project#milestones.size, Project#milestones, Project#milestones<<(milestone),</tt>
    #   <tt>Project#milestones.delete(milestone), Project#milestones.find(milestone_id), Project#milestones.find(:all, options),</tt>
    #   <tt>Project#milestones.build, Project#milestones.create</tt>
    # * <tt>Project#categories.empty?, Project#categories.size, Project#categories, Project#categories<<(category1),</tt>
    #   <tt>Project#categories.delete(category1)</tt>
    #
    # === A word of warning
    #
    # Don't create associations that have the same name as instance methods of
    # <tt>ActiveRecord::Base</tt>. Since the association adds a method with that name to
    # its model, it will override the inherited method and break things.
    # For instance, +attributes+ and +connection+ would be bad choices for association names.
    #
    # == Auto-generated methods
    #
    # === Singular associations (one-to-one)
    #                                     |            |  belongs_to  |
    #   generated methods                 | belongs_to | :polymorphic | has_one
    #   ----------------------------------+------------+--------------+---------
    #   other                             |     X      |      X       |    X
    #   other=(other)                     |     X      |      X       |    X
    #   build_other(attributes={})        |     X      |              |    X
    #   create_other(attributes={})       |     X      |              |    X
    #   other.create!(attributes={})      |            |              |    X
    #
    # ===Collection associations (one-to-many / many-to-many)
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
    #   others.sum(args*,&block)          |   X   |    X     |    X
    #   others.empty?                     |   X   |    X     |    X
    #   others.clear                      |   X   |    X     |    X
    #   others.delete(other,other,...)    |   X   |    X     |    X
    #   others.delete_all                 |   X   |    X     |
    #   others.destroy_all                |   X   |    X     |    X
    #   others.find(*args)                |   X   |    X     |    X
    #   others.find_first                 |   X   |          |
    #   others.exists?                    |   X   |    X     |    X
    #   others.uniq                       |   X   |    X     |    X
    #   others.reset                      |   X   |    X     |    X
    #
    # == Cardinality and associations
    #
    # Active Record associations can be used to describe one-to-one, one-to-many and many-to-many
    # relationships between models. Each model uses an association to describe its role in
    # the relation. The +belongs_to+ association is always used in the model that has
    # the foreign key.
    #
    # === One-to-one
    #
    # Use +has_one+ in the base, and +belongs_to+ in the associated model.
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
    # Use +has_many+ in the base, and +belongs_to+ in the associated model.
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
    # The first way uses a +has_many+ association with the <tt>:through</tt> option and a join model, so
    # there are two stages of associations.
    #
    #   class Assignment < ActiveRecord::Base
    #     belongs_to :programmer  # foreign key - programmer_id
    #     belongs_to :project     # foreign key - project_id
    #   end
    #   class Programmer < ActiveRecord::Base
    #     has_many :assignments
    #     has_many :projects, :through => :assignments
    #   end
    #   class Project < ActiveRecord::Base
    #     has_many :assignments
    #     has_many :programmers, :through => :assignments
    #   end
    #
    # For the second way, use +has_and_belongs_to_many+ in both models. This requires a join table
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
    # use <tt>has_many :through</tt>. Use +has_and_belongs_to_many+ when working with legacy schemas or when
    # you never work directly with the relationship itself.
    #
    # == Is it a +belongs_to+ or +has_one+ association?
    #
    # Both express a 1-1 relationship. The difference is mostly where to place the foreign
    # key, which goes on the table for the class declaring the +belongs_to+ relationship.
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
    #     id int(11) NOT NULL auto_increment,
    #     account_id int(11) default NULL,
    #     name varchar default NULL,
    #     PRIMARY KEY  (id)
    #   )
    #
    #   CREATE TABLE accounts (
    #     id int(11) NOT NULL auto_increment,
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
    # You can set the :autosave option on a <tt>has_one</tt>, <tt>belongs_to</tt>,
    # <tt>has_many</tt>, or <tt>has_and_belongs_to_many</tt> association. Setting it
    # to +true+ will _always_ save the members, whereas setting it to +false+ will
    # _never_ save the members. More details about :autosave option is available at
    # autosave_association.rb .
    #
    # === One-to-one associations
    #
    # * Assigning an object to a +has_one+ association automatically saves that object and
    # the object being replaced (if there is one), in order to update their primary
    # keys - except if the parent object is unsaved (<tt>new_record? == true</tt>).
    # * If either of these saves fail (due to one of the objects being invalid) the assignment
    # statement returns +false+ and the assignment is cancelled.
    # * If you wish to assign an object to a +has_one+ association without saving it,
    # use the <tt>association.build</tt> method (documented below).
    # * Assigning an object to a +belongs_to+ association does not save the object, since
    # the foreign key field belongs on the parent. It does not save the parent either.
    #
    # === Collections
    #
    # * Adding an object to a collection (+has_many+ or +has_and_belongs_to_many+) automatically
    # saves that object, except if the parent object (the owner of the collection) is not yet
    # stored in the database.
    # * If saving any of the objects being added to a collection (via <tt>push</tt> or similar)
    # fails, then <tt>push</tt> returns +false+.
    # * You can add an object to a collection without automatically saving it by using the
    # <tt>collection.build</tt> method (documented below).
    # * All unsaved (<tt>new_record? == true</tt>) members of the collection are automatically
    # saved when the parent is saved.
    #
    # === Association callbacks
    #
    # Similar to the normal callbacks that hook into the life cycle of an Active Record object,
    # you can also define callbacks that get triggered when you add an object to or remove an
    # object from an association collection.
    #
    #   class Project
    #     has_and_belongs_to_many :developers, :after_add => :evaluate_velocity
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
    #                             :after_add => [:evaluate_velocity, Proc.new { |p, d| p.shipping_date = Time.now}]
    #   end
    #
    # Possible callbacks are: +before_add+, +after_add+, +before_remove+ and +after_remove+.
    #
    # Should any of the +before_add+ callbacks throw an exception, the object does not get
    # added to the collection. Same with the +before_remove+ callbacks; if an exception is
    # thrown the object doesn't get removed.
    #
    # === Association extensions
    #
    # The proxy objects that control the access to associations can be extended through anonymous
    # modules. This is especially beneficial for adding new finders, creators, and other
    # factory-type methods that are only used as part of this association.
    #
    #   class Account < ActiveRecord::Base
    #     has_many :people do
    #       def find_or_create_by_name(name)
    #         first_name, last_name = name.split(" ", 2)
    #         find_or_create_by_first_name_and_last_name(first_name, last_name)
    #       end
    #     end
    #   end
    #
    #   person = Account.find(:first).people.find_or_create_by_name("David Heinemeier Hansson")
    #   person.first_name # => "David"
    #   person.last_name  # => "Heinemeier Hansson"
    #
    # If you need to share the same extensions between many associations, you can use a named
    # extension module.
    #
    #   module FindOrCreateByNameExtension
    #     def find_or_create_by_name(name)
    #       first_name, last_name = name.split(" ", 2)
    #       find_or_create_by_first_name_and_last_name(first_name, last_name)
    #     end
    #   end
    #
    #   class Account < ActiveRecord::Base
    #     has_many :people, :extend => FindOrCreateByNameExtension
    #   end
    #
    #   class Company < ActiveRecord::Base
    #     has_many :people, :extend => FindOrCreateByNameExtension
    #   end
    #
    # If you need to use multiple named extension modules, you can specify an array of modules
    # with the <tt>:extend</tt> option.
    # In the case of name conflicts between methods in the modules, methods in modules later
    # in the array supercede those earlier in the array.
    #
    #   class Account < ActiveRecord::Base
    #     has_many :people, :extend => [FindOrCreateByNameExtension, FindRecentExtension]
    #   end
    #
    # Some extensions can only be made to work with knowledge of the association proxy's internals.
    # Extensions can access relevant state using accessors on the association proxy:
    #
    # * +proxy_owner+ - Returns the object the association is part of.
    # * +proxy_reflection+ - Returns the reflection object that describes the association.
    # * +proxy_target+ - Returns the associated object for +belongs_to+ and +has_one+, or
    #   the collection of associated objects for +has_many+ and +has_and_belongs_to_many+.
    #
    # === Association Join Models
    #
    # Has Many associations can be configured with the <tt>:through</tt> option to use an
    # explicit join model to retrieve the data.  This operates similarly to a
    # +has_and_belongs_to_many+ association.  The advantage is that you're able to add validations,
    # callbacks, and extra attributes on the join model.  Consider the following schema:
    #
    #   class Author < ActiveRecord::Base
    #     has_many :authorships
    #     has_many :books, :through => :authorships
    #   end
    #
    #   class Authorship < ActiveRecord::Base
    #     belongs_to :author
    #     belongs_to :book
    #   end
    #
    #   @author = Author.find :first
    #   @author.authorships.collect { |a| a.book } # selects all books that the author's authorships belong to
    #   @author.books                              # selects all books by using the Authorship join model
    #
    # You can also go through a +has_many+ association on the join model:
    #
    #   class Firm < ActiveRecord::Base
    #     has_many   :clients
    #     has_many   :invoices, :through => :clients
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
    #   @firm = Firm.find :first
    #   @firm.clients.collect { |c| c.invoices }.flatten # select all invoices for all clients of the firm
    #   @firm.invoices                                   # selects all invoices by going through the Client join model
    #
    # Similarly you can go through a +has_one+ association on the join model:
    #
    #   class Group < ActiveRecord::Base
    #     has_many   :users
    #     has_many   :avatars, :through => :users
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
    #   @group.users.collect { |u| u.avatar }.flatten # select all avatars for all users in the group
    #   @group.avatars                                # selects all avatars by going through the User join model.
    #
    # An important caveat with going through +has_one+ or +has_many+ associations on the
    # join model is that these associations are *read-only*.  For example, the following
    # would not work following the previous example:
    #
    #   @group.avatars << Avatar.new   # this would work if User belonged_to Avatar rather than the other way around
    #   @group.avatars.delete(@group.avatars.last)  # so would this
    #
    # === Polymorphic Associations
    #
    # Polymorphic associations on models are not restricted on what types of models they
    # can be associated with.  Rather, they specify an interface that a +has_many+ association
    # must adhere to.
    #
    #   class Asset < ActiveRecord::Base
    #     belongs_to :attachable, :polymorphic => true
    #   end
    #
    #   class Post < ActiveRecord::Base
    #     has_many :assets, :as => :attachable         # The :as option specifies the polymorphic interface to use.
    #   end
    #
    #   @asset.attachable = @post
    #
    # This works by using a type column in addition to a foreign key to specify the associated
    # record.  In the Asset example, you'd need an +attachable_id+ integer column and an
    # +attachable_type+ string column.
    #
    # Using polymorphic associations in combination with single table inheritance (STI) is
    # a little tricky. In order for the associations to work as expected, ensure that you
    # store the base model for the STI models in the type column of the polymorphic
    # association. To continue with the asset example above, suppose there are guest posts
    # and member posts that use the posts table for STI. In this case, there must be a +type+
    # column in the posts table.
    #
    #   class Asset < ActiveRecord::Base
    #     belongs_to :attachable, :polymorphic => true
    #
    #     def attachable_type=(sType)
    #        super(sType.to_s.classify.constantize.base_class.to_s)
    #     end
    #   end
    #
    #   class Post < ActiveRecord::Base
    #     # because we store "Post" in attachable_type now :dependent => :destroy will work
    #     has_many :assets, :as => :attachable, :dependent => :destroy
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
    #   project.milestones(true).size  # fetches milestones from the database
    #   project.milestones             # uses the milestone cache
    #
    # == Eager loading of associations
    #
    # Eager loading is a way to find objects of a certain class and a number of named associations.
    # This is one of the easiest ways of to prevent the dreaded 1+N problem in which fetching 100
    # posts that each need to display their author triggers 101 database queries. Through the
    # use of eager loading, the 101 queries can be reduced to 2.
    #
    #   class Post < ActiveRecord::Base
    #     belongs_to :author
    #     has_many   :comments
    #   end
    #
    # Consider the following loop using the class above:
    #
    #   for post in Post.all
    #     puts "Post:            " + post.title
    #     puts "Written by:      " + post.author.name
    #     puts "Last comment on: " + post.comments.first.created_on
    #   end
    #
    # To iterate over these one hundred posts, we'll generate 201 database queries. Let's
    # first just optimize it for retrieving the author:
    #
    #   for post in Post.find(:all, :include => :author)
    #
    # This references the name of the +belongs_to+ association that also used the <tt>:author</tt>
    # symbol. After loading the posts, find will collect the +author_id+ from each one and load
    # all the referenced authors with one query. Doing so will cut down the number of queries
    # from 201 to 102.
    #
    # We can improve upon the situation further by referencing both associations in the finder with:
    #
    #   for post in Post.find(:all, :include => [ :author, :comments ])
    #
    # This will load all comments with a single query. This reduces the total number of queries
    # to 3. More generally the number of queries will be 1 plus the number of associations
    # named (except if some of the associations are polymorphic +belongs_to+ - see below).
    #
    # To include a deep hierarchy of associations, use a hash:
    #
    #   for post in Post.find(:all, :include => [ :author, { :comments => { :author => :gravatar } } ])
    #
    # That'll grab not only all the comments but all their authors and gravatar pictures.
    # You can mix and match symbols, arrays and hashes in any combination to describe the
    # associations you want to load.
    #
    # All of this power shouldn't fool you into thinking that you can pull out huge amounts
    # of data with no performance penalty just because you've reduced the number of queries.
    # The database still needs to send all the data to Active Record and it still needs to
    # be processed. So it's no catch-all for performance problems, but it's a great way to
    # cut down on the number of queries in a situation as the one described above.
    #
    # Since only one table is loaded at a time, conditions or orders cannot reference tables
    # other than the main one. If this is the case Active Record falls back to the previously
    # used LEFT OUTER JOIN based strategy. For example
    #
    #   Post.includes([:author, :comments]).where(['comments.approved = ?', true]).all
    #
    # This will result in a single SQL query with joins along the lines of:
    # <tt>LEFT OUTER JOIN comments ON comments.post_id = posts.id</tt> and
    # <tt>LEFT OUTER JOIN authors ON authors.id = posts.author_id</tt>. Note that using conditions
    # like this can have unintended consequences.
    # In the above example posts with no approved comments are not returned at all, because
    # the conditions apply to the SQL statement as a whole and not just to the association.
    # You must disambiguate column references for this fallback to happen, for example
    # <tt>:order => "author.name DESC"</tt> will work but <tt>:order => "name DESC"</tt> will not.
    #
    # If you do want eager load only some members of an association it is usually more natural
    # to <tt>:include</tt> an association which has conditions defined on it:
    #
    #   class Post < ActiveRecord::Base
    #     has_many :approved_comments, :class_name => 'Comment', :conditions => ['approved = ?', true]
    #   end
    #
    #   Post.find(:all, :include => :approved_comments)
    #
    # This will load posts and eager load the +approved_comments+ association, which contains
    # only those comments that have been approved.
    #
    # If you eager load an association with a specified <tt>:limit</tt> option, it will be ignored,
    # returning all the associated objects:
    #
    #   class Picture < ActiveRecord::Base
    #     has_many :most_recent_comments, :class_name => 'Comment', :order => 'id DESC', :limit => 10
    #   end
    #
    #   Picture.find(:first, :include => :most_recent_comments).most_recent_comments # => returns all associated comments.
    #
    # When eager loaded, conditions are interpolated in the context of the model class, not
    # the model instance.  Conditions are lazily interpolated before the actual model exists.
    #
    # Eager loading is supported with polymorphic associations.
    #
    #   class Address < ActiveRecord::Base
    #     belongs_to :addressable, :polymorphic => true
    #   end
    #
    # A call that tries to eager load the addressable model
    #
    #   Address.find(:all, :include => :addressable)
    #
    # This will execute one query to load the addresses and load the addressables with one
    # query per addressable type.
    # For example if all the addressables are either of class Person or Company then a total
    # of 3 queries will be executed. The list of addressable types to load is determined on
    # the back of the addresses loaded. This is not supported if Active Record has to fallback
    # to the previous implementation of eager loading and will raise ActiveRecord::EagerLoadPolymorphicError.
    # The reason is that the parent model's type is a column value so its corresponding table
    # name cannot be put in the +FROM+/+JOIN+ clauses of that query.
    #
    # == Table Aliasing
    #
    # Active Record uses table aliasing in the case that a table is referenced multiple times
    # in a join.  If a table is referenced only once, the standard table name is used.  The
    # second time, the table is aliased as <tt>#{reflection_name}_#{parent_table_name}</tt>.
    # Indexes are appended for any more successive uses of the table name.
    #
    #   Post.find :all, :joins => :comments
    #   # => SELECT ... FROM posts INNER JOIN comments ON ...
    #   Post.find :all, :joins => :special_comments # STI
    #   # => SELECT ... FROM posts INNER JOIN comments ON ... AND comments.type = 'SpecialComment'
    #   Post.find :all, :joins => [:comments, :special_comments] # special_comments is the reflection name, posts is the parent table name
    #   # => SELECT ... FROM posts INNER JOIN comments ON ... INNER JOIN comments special_comments_posts
    #
    # Acts as tree example:
    #
    #   TreeMixin.find :all, :joins => :children
    #   # => SELECT ... FROM mixins INNER JOIN mixins childrens_mixins ...
    #   TreeMixin.find :all, :joins => {:children => :parent}
    #   # => SELECT ... FROM mixins INNER JOIN mixins childrens_mixins ...
    #                               INNER JOIN parents_mixins ...
    #   TreeMixin.find :all, :joins => {:children => {:parent => :children}}
    #   # => SELECT ... FROM mixins INNER JOIN mixins childrens_mixins ...
    #                               INNER JOIN parents_mixins ...
    #                               INNER JOIN mixins childrens_mixins_2
    #
    # Has and Belongs to Many join tables use the same idea, but add a <tt>_join</tt> suffix:
    #
    #   Post.find :all, :joins => :categories
    #   # => SELECT ... FROM posts INNER JOIN categories_posts ... INNER JOIN categories ...
    #   Post.find :all, :joins => {:categories => :posts}
    #   # => SELECT ... FROM posts INNER JOIN categories_posts ... INNER JOIN categories ...
    #                              INNER JOIN categories_posts posts_categories_join INNER JOIN posts posts_categories
    #   Post.find :all, :joins => {:categories => {:posts => :categories}}
    #   # => SELECT ... FROM posts INNER JOIN categories_posts ... INNER JOIN categories ...
    #                              INNER JOIN categories_posts posts_categories_join INNER JOIN posts posts_categories
    #                              INNER JOIN categories_posts categories_posts_join INNER JOIN categories categories_posts_2
    #
    # If you wish to specify your own custom joins using a <tt>:joins</tt> option, those table
    # names will take precedence over the eager associations:
    #
    #   Post.find :all, :joins => :comments, :joins => "inner join comments ..."
    #   # => SELECT ... FROM posts INNER JOIN comments_posts ON ... INNER JOIN comments ...
    #   Post.find :all, :joins => [:comments, :special_comments], :joins => "inner join comments ..."
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
    #          has_many :clients
    #        end
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
    #         belongs_to :firm, :class_name => "MyApplication::Business::Firm"
    #       end
    #     end
    #   end
    #
    # == Bi-directional associations
    #
    # When you specify an association there is usually an association on the associated model
    # that specifies the same relationship in reverse.  For example, with the following models:
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
    # The +traps+ association on +Dungeon+ and the the +dungeon+ association on +Trap+ are
    # the inverse of each other and the inverse of the +dungeon+ association on +EvilWizard+
    # is the +evil_wizard+ association on +Dungeon+ (and vice-versa).  By default,
    # Active Record doesn't know anything about these inverse relationships and so no object
    # loading optimisation is possible.  For example:
    #
    #    d = Dungeon.first
    #    t = d.traps.first
    #    d.level == t.dungeon.level # => true
    #    d.level = 10
    #    d.level == t.dungeon.level # => false
    #
    # The +Dungeon+ instances +d+ and <tt>t.dungeon</tt> in the above example refer to
    # the same object data from the database, but are actually different in-memory copies
    # of that data.  Specifying the <tt>:inverse_of</tt> option on associations lets you tell
    # Active Record about inverse relationships and it will optimise object loading.  For
    # example, if we changed our model definitions to:
    #
    #    class Dungeon < ActiveRecord::Base
    #      has_many :traps, :inverse_of => :dungeon
    #      has_one :evil_wizard, :inverse_of => :dungeon
    #    end
    #
    #    class Trap < ActiveRecord::Base
    #      belongs_to :dungeon, :inverse_of => :traps
    #    end
    #
    #    class EvilWizard < ActiveRecord::Base
    #      belongs_to :dungeon, :inverse_of => :evil_wizard
    #    end
    #
    # Then, from our code snippet above, +d+ and <tt>t.dungeon</tt> are actually the same
    # in-memory instance and our final <tt>d.level == t.dungeon.level</tt> will return +true+.
    #
    # There are limitations to <tt>:inverse_of</tt> support:
    #
    # * does not work with <tt>:through</tt> associations.
    # * does not work with <tt>:polymorphic</tt> associations.
    # * for +belongs_to+ associations +has_many+ inverse associations are ignored.
    #
    # == Type safety with <tt>ActiveRecord::AssociationTypeMismatch</tt>
    #
    # If you attempt to assign an object to an association that doesn't match the inferred
    # or specified <tt>:class_name</tt>, you'll get an <tt>ActiveRecord::AssociationTypeMismatch</tt>.
    #
    # == Options
    #
    # All of the association macros can be specialized through options. This makes cases
    # more complex than the simple and guessable ones possible.
    module ClassMethods
      # Specifies a one-to-many association. The following methods for retrieval and query of
      # collections of associated objects will be added:
      #
      # [collection(force_reload = false)]
      #   Returns an array of all the associated objects.
      #   An empty array is returned if none are found.
      # [collection<<(object, ...)]
      #   Adds one or more objects to the collection by setting their foreign keys to the collection's primary key.
      #   Note that this operation instantly fires update sql without waiting for the save or update call on the
      #   parent object.
      # [collection.delete(object, ...)]
      #   Removes one or more objects from the collection by setting their foreign keys to +NULL+.
      #   Objects will be in addition destroyed if they're associated with <tt>:dependent => :destroy</tt>,
      #   and deleted if they're associated with <tt>:dependent => :delete_all</tt>.
      # [collection=objects]
      #   Replaces the collections content by deleting and adding objects as appropriate. If the <tt>:through</tt>
      #   option is true callbacks in the join models are triggered except destroy callbacks, since deletion is
      #   direct.
      # [collection_singular_ids]
      #   Returns an array of the associated objects' ids
      # [collection_singular_ids=ids]
      #   Replace the collection with the objects identified by the primary keys in +ids+. This
      #   method loads the models and calls <tt>collection=</tt>. See above.
      # [collection.clear]
      #   Removes every object from the collection. This destroys the associated objects if they
      #   are associated with <tt>:dependent => :destroy</tt>, deletes them directly from the
      #   database if <tt>:dependent => :delete_all</tt>, otherwise sets their foreign keys to +NULL+.
      #   If the <tt>:through</tt> option is true no destroy callbacks are invoked on the join models.
      #   Join models are directly deleted.
      # [collection.empty?]
      #   Returns +true+ if there are no associated objects.
      # [collection.size]
      #   Returns the number of associated objects.
      # [collection.find(...)]
      #   Finds an associated object according to the same rules as ActiveRecord::Base.find.
      # [collection.exists?(...)]
      #   Checks whether an associated object with the given conditions exists.
      #   Uses the same rules as ActiveRecord::Base.exists?.
      # [collection.build(attributes = {}, ...)]
      #   Returns one or more new objects of the collection type that have been instantiated
      #   with +attributes+ and linked to this object through a foreign key, but have not yet
      #   been saved.
      # [collection.create(attributes = {})]
      #   Returns a new object of the collection type that has been instantiated
      #   with +attributes+, linked to this object through a foreign key, and that has already
      #   been saved (if it passed the validation). *Note*: This only works if the base model
      #   already exists in the DB, not if it is a new (unsaved) record!
      #
      # (*Note*: +collection+ is replaced with the symbol passed as the first argument, so
      # <tt>has_many :clients</tt> would add among others <tt>clients.empty?</tt>.)
      #
      # === Example
      #
      # Example: A Firm class declares <tt>has_many :clients</tt>, which will add:
      # * <tt>Firm#clients</tt> (similar to <tt>Clients.find :all, :conditions => ["firm_id = ?", id]</tt>)
      # * <tt>Firm#clients<<</tt>
      # * <tt>Firm#clients.delete</tt>
      # * <tt>Firm#clients=</tt>
      # * <tt>Firm#client_ids</tt>
      # * <tt>Firm#client_ids=</tt>
      # * <tt>Firm#clients.clear</tt>
      # * <tt>Firm#clients.empty?</tt> (similar to <tt>firm.clients.size == 0</tt>)
      # * <tt>Firm#clients.size</tt> (similar to <tt>Client.count "firm_id = #{id}"</tt>)
      # * <tt>Firm#clients.find</tt> (similar to <tt>Client.find(id, :conditions => "firm_id = #{id}")</tt>)
      # * <tt>Firm#clients.exists?(:name => 'ACME')</tt> (similar to <tt>Client.exists?(:name => 'ACME', :firm_id => firm.id)</tt>)
      # * <tt>Firm#clients.build</tt> (similar to <tt>Client.new("firm_id" => id)</tt>)
      # * <tt>Firm#clients.create</tt> (similar to <tt>c = Client.new("firm_id" => id); c.save; c</tt>)
      # The declaration can also include an options hash to specialize the behavior of the association.
      #
      # === Supported options
      # [:class_name]
      #   Specify the class name of the association. Use it only if that name can't be inferred
      #   from the association name. So <tt>has_many :products</tt> will by default be linked
      #   to the Product class, but if the real class name is SpecialProduct, you'll have to
      #   specify it with this option.
      # [:conditions]
      #   Specify the conditions that the associated objects must meet in order to be included as a +WHERE+
      #   SQL fragment, such as <tt>price > 5 AND name LIKE 'B%'</tt>.  Record creations from
      #   the association are scoped if a hash is used.
      #   <tt>has_many :posts, :conditions => {:published => true}</tt> will create published
      #   posts with <tt>@blog.posts.create</tt> or <tt>@blog.posts.build</tt>.
      # [:order]
      #   Specify the order in which the associated objects are returned as an <tt>ORDER BY</tt> SQL fragment,
      #   such as <tt>last_name, first_name DESC</tt>.
      # [:foreign_key]
      #   Specify the foreign key used for the association. By default this is guessed to be the name
      #   of this class in lower-case and "_id" suffixed. So a Person class that makes a +has_many+
      #   association will use "person_id" as the default <tt>:foreign_key</tt>.
      # [:primary_key]
      #   Specify the method that returns the primary key used for the association. By default this is +id+.
      # [:dependent]
      #   If set to <tt>:destroy</tt> all the associated objects are destroyed
      #   alongside this object by calling their +destroy+ method.  If set to <tt>:delete_all</tt> all associated
      #   objects are deleted *without* calling their +destroy+ method.  If set to <tt>:nullify</tt> all associated
      #   objects' foreign keys are set to +NULL+ *without* calling their +save+ callbacks. If set to
      #   <tt>:restrict</tt> this object cannot be deleted if it has any associated object.
      #
      #   *Warning:* This option is ignored when used with <tt>:through</tt> option.
      #
      # [:finder_sql]
      #   Specify a complete SQL statement to fetch the association. This is a good way to go for complex
      #   associations that depend on multiple tables. Note: When this option is used, +find_in_collection+
      #   is _not_ added.
      # [:counter_sql]
      #   Specify a complete SQL statement to fetch the size of the association. If <tt>:finder_sql</tt> is
      #   specified but not <tt>:counter_sql</tt>, <tt>:counter_sql</tt> will be generated by
      #   replacing <tt>SELECT ... FROM</tt> with <tt>SELECT COUNT(*) FROM</tt>.
      # [:extend]
      #   Specify a named module for extending the proxy. See "Association extensions".
      # [:include]
      #   Specify second-order associations that should be eager loaded when the collection is loaded.
      # [:group]
      #   An attribute name by which the result should be grouped. Uses the <tt>GROUP BY</tt> SQL-clause.
      # [:having]
      #   Combined with +:group+ this can be used to filter the records that a <tt>GROUP BY</tt>
      #   returns. Uses the <tt>HAVING</tt> SQL-clause.
      # [:limit]
      #   An integer determining the limit on the number of rows that should be returned.
      # [:offset]
      #   An integer determining the offset from where the rows should be fetched. So at 5,
      #   it would skip the first 4 rows.
      # [:select]
      #   By default, this is <tt>*</tt> as in <tt>SELECT * FROM</tt>, but can be changed if
      #   you, for example, want to do a join but not include the joined columns. Do not forget
      #   to include the primary and foreign keys, otherwise it will raise an error.
      # [:as]
      #   Specifies a polymorphic interface (See <tt>belongs_to</tt>).
      # [:through]
      #   Specifies a join model through which to perform the query.  Options for <tt>:class_name</tt>
      #   and <tt>:foreign_key</tt> are ignored, as the association uses the source reflection. You
      #   can only use a <tt>:through</tt> query through a <tt>belongs_to</tt>, <tt>has_one</tt>
      #   or <tt>has_many</tt> association on the join model. The collection of join models
      #   can be managed via the collection API. For example, new join models are created for
      #   newly associated objects, and if some are gone their rows are deleted (directly,
      #   no destroy callbacks are triggered).
      # [:source]
      #   Specifies the source association name used by <tt>has_many :through</tt> queries.
      #   Only use it if the name cannot be inferred from the association.
      #   <tt>has_many :subscribers, :through => :subscriptions</tt> will look for either <tt>:subscribers</tt> or
      #   <tt>:subscriber</tt> on Subscription, unless a <tt>:source</tt> is given.
      # [:source_type]
      #   Specifies type of the source association used by <tt>has_many :through</tt> queries where the source
      #   association is a polymorphic +belongs_to+.
      # [:uniq]
      #   If true, duplicates will be omitted from the collection. Useful in conjunction with <tt>:through</tt>.
      # [:readonly]
      #   If true, all the associated objects are readonly through the association.
      # [:validate]
      #   If +false+, don't validate the associated objects when saving the parent object. true by default.
      # [:autosave]
      #   If true, always save the associated objects or destroy them if marked for destruction,
      #   when saving the parent object. If false, never save or destroy the associated objects.
      #   By default, only save associated objects that are new records.
      # [:inverse_of]
      #   Specifies the name of the <tt>belongs_to</tt> association on the associated object
      #   that is the inverse of this <tt>has_many</tt> association. Does not work in combination
      #   with <tt>:through</tt> or <tt>:as</tt> options.
      #   See ActiveRecord::Associations::ClassMethods's overview on Bi-directional associations for more detail.
      #
      # Option examples:
      #   has_many :comments, :order => "posted_on"
      #   has_many :comments, :include => :author
      #   has_many :people, :class_name => "Person", :conditions => "deleted = 0", :order => "name"
      #   has_many :tracks, :order => "position", :dependent => :destroy
      #   has_many :comments, :dependent => :nullify
      #   has_many :tags, :as => :taggable
      #   has_many :reports, :readonly => true
      #   has_many :subscribers, :through => :subscriptions, :source => :user
      #   has_many :subscribers, :class_name => "Person", :finder_sql =>
      #       'SELECT DISTINCT people.* ' +
      #       'FROM people p, post_subscriptions ps ' +
      #       'WHERE ps.post_id = #{id} AND ps.person_id = p.id ' +
      #       'ORDER BY p.first_name'
      def has_many(association_id, options = {}, &extension)
        reflection = create_has_many_reflection(association_id, options, &extension)
        configure_dependency_for_has_many(reflection)
        add_association_callbacks(reflection.name, reflection.options)

        if options[:through]
          collection_accessor_methods(reflection, HasManyThroughAssociation)
        else
          collection_accessor_methods(reflection, HasManyAssociation)
        end
      end

      # Specifies a one-to-one association with another class. This method should only be used
      # if the other class contains the foreign key. If the current class contains the foreign key,
      # then you should use +belongs_to+ instead. See also ActiveRecord::Associations::ClassMethods's overview
      # on when to use has_one and when to use belongs_to.
      #
      # The following methods for retrieval and query of a single associated object will be added:
      #
      # [association(force_reload = false)]
      #   Returns the associated object. +nil+ is returned if none is found.
      # [association=(associate)]
      #   Assigns the associate object, extracts the primary key, sets it as the foreign key,
      #   and saves the associate object.
      # [build_association(attributes = {})]
      #   Returns a new object of the associated type that has been instantiated
      #   with +attributes+ and linked to this object through a foreign key, but has not
      #   yet been saved. <b>Note:</b> This ONLY works if an association already exists.
      #   It will NOT work if the association is +nil+.
      # [create_association(attributes = {})]
      #   Returns a new object of the associated type that has been instantiated
      #   with +attributes+, linked to this object through a foreign key, and that
      #   has already been saved (if it passed the validation).
      #
      # (+association+ is replaced with the symbol passed as the first argument, so
      # <tt>has_one :manager</tt> would add among others <tt>manager.nil?</tt>.)
      #
      # === Example
      #
      # An Account class declares <tt>has_one :beneficiary</tt>, which will add:
      # * <tt>Account#beneficiary</tt> (similar to <tt>Beneficiary.find(:first, :conditions => "account_id = #{id}")</tt>)
      # * <tt>Account#beneficiary=(beneficiary)</tt> (similar to <tt>beneficiary.account_id = account.id; beneficiary.save</tt>)
      # * <tt>Account#build_beneficiary</tt> (similar to <tt>Beneficiary.new("account_id" => id)</tt>)
      # * <tt>Account#create_beneficiary</tt> (similar to <tt>b = Beneficiary.new("account_id" => id); b.save; b</tt>)
      #
      # === Options
      #
      # The declaration can also include an options hash to specialize the behavior of the association.
      #
      # Options are:
      # [:class_name]
      #   Specify the class name of the association. Use it only if that name can't be inferred
      #   from the association name. So <tt>has_one :manager</tt> will by default be linked to the Manager class, but
      #   if the real class name is Person, you'll have to specify it with this option.
      # [:conditions]
      #   Specify the conditions that the associated object must meet in order to be included as a +WHERE+
      #   SQL fragment, such as <tt>rank = 5</tt>. Record creation from the association is scoped if a hash
      #   is used. <tt>has_one :account, :conditions => {:enabled => true}</tt> will create
      #   an enabled account with <tt>@company.create_account</tt> or <tt>@company.build_account</tt>.
      # [:order]
      #   Specify the order in which the associated objects are returned as an <tt>ORDER BY</tt> SQL fragment,
      #   such as <tt>last_name, first_name DESC</tt>.
      # [:dependent]
      #   If set to <tt>:destroy</tt>, the associated object is destroyed when this object is. If set to
      #   <tt>:delete</tt>, the associated object is deleted *without* calling its destroy method.
      #   If set to <tt>:nullify</tt>, the associated object's foreign key is set to +NULL+.
      #   Also, association is assigned.
      # [:foreign_key]
      #   Specify the foreign key used for the association. By default this is guessed to be the name
      #   of this class in lower-case and "_id" suffixed. So a Person class that makes a +has_one+ association
      #   will use "person_id" as the default <tt>:foreign_key</tt>.
      # [:primary_key]
      #   Specify the method that returns the primary key used for the association. By default this is +id+.
      # [:include]
      #   Specify second-order associations that should be eager loaded when this object is loaded.
      # [:as]
      #   Specifies a polymorphic interface (See <tt>belongs_to</tt>).
      # [:select]
      #   By default, this is <tt>*</tt> as in <tt>SELECT * FROM</tt>, but can be changed if, for example,
      #   you want to do a join but not include the joined columns. Do not forget to include the
      #   primary and foreign keys, otherwise it will raise an error.
      # [:through]
      #   Specifies a Join Model through which to perform the query.  Options for <tt>:class_name</tt>
      #   and <tt>:foreign_key</tt> are ignored, as the association uses the source reflection. You
      #   can only use a <tt>:through</tt> query through a <tt>has_one</tt> or <tt>belongs_to</tt>
      #   association on the join model.
      # [:source]
      #   Specifies the source association name used by <tt>has_one :through</tt> queries.
      #   Only use it if the name cannot be inferred from the association.
      #   <tt>has_one :favorite, :through => :favorites</tt> will look for a
      #   <tt>:favorite</tt> on Favorite, unless a <tt>:source</tt> is given.
      # [:source_type]
      #   Specifies type of the source association used by <tt>has_one :through</tt> queries where the source
      #   association is a polymorphic +belongs_to+.
      # [:readonly]
      #   If true, the associated object is readonly through the association.
      # [:validate]
      #   If +false+, don't validate the associated object when saving the parent object. +false+ by default.
      # [:autosave]
      #   If true, always save the associated object or destroy it if marked for destruction,
      #   when saving the parent object. If false, never save or destroy the associated object.
      #   By default, only save the associated object if it's a new record.
      # [:inverse_of]
      #   Specifies the name of the <tt>belongs_to</tt> association on the associated object
      #   that is the inverse of this <tt>has_one</tt> association.  Does not work in combination
      #   with <tt>:through</tt> or <tt>:as</tt> options.
      #   See ActiveRecord::Associations::ClassMethods's overview on Bi-directional associations for more detail.
      #
      # Option examples:
      #   has_one :credit_card, :dependent => :destroy  # destroys the associated credit card
      #   has_one :credit_card, :dependent => :nullify  # updates the associated records foreign
      #                                                 # key value to NULL rather than destroying it
      #   has_one :last_comment, :class_name => "Comment", :order => "posted_on"
      #   has_one :project_manager, :class_name => "Person", :conditions => "role = 'project_manager'"
      #   has_one :attachment, :as => :attachable
      #   has_one :boss, :readonly => :true
      #   has_one :club, :through => :membership
      #   has_one :primary_address, :through => :addressables, :conditions => ["addressable.primary = ?", true], :source => :addressable
      def has_one(association_id, options = {})
        if options[:through]
          reflection = create_has_one_through_reflection(association_id, options)
          association_accessor_methods(reflection, ActiveRecord::Associations::HasOneThroughAssociation)
        else
          reflection = create_has_one_reflection(association_id, options)
          association_accessor_methods(reflection, HasOneAssociation)
          association_constructor_method(:build,  reflection, HasOneAssociation)
          association_constructor_method(:create, reflection, HasOneAssociation)
          configure_dependency_for_has_one(reflection)
        end
      end

      # Specifies a one-to-one association with another class. This method should only be used
      # if this class contains the foreign key. If the other class contains the foreign key,
      # then you should use +has_one+ instead. See also ActiveRecord::Associations::ClassMethods's overview
      # on when to use +has_one+ and when to use +belongs_to+.
      #
      # Methods will be added for retrieval and query for a single associated object, for which
      # this object holds an id:
      #
      # [association(force_reload = false)]
      #   Returns the associated object. +nil+ is returned if none is found.
      # [association=(associate)]
      #   Assigns the associate object, extracts the primary key, and sets it as the foreign key.
      # [build_association(attributes = {})]
      #   Returns a new object of the associated type that has been instantiated
      #   with +attributes+ and linked to this object through a foreign key, but has not yet been saved.
      # [create_association(attributes = {})]
      #   Returns a new object of the associated type that has been instantiated
      #   with +attributes+, linked to this object through a foreign key, and that
      #   has already been saved (if it passed the validation).
      #
      # (+association+ is replaced with the symbol passed as the first argument, so
      # <tt>belongs_to :author</tt> would add among others <tt>author.nil?</tt>.)
      #
      # === Example
      #
      # A Post class declares <tt>belongs_to :author</tt>, which will add:
      # * <tt>Post#author</tt> (similar to <tt>Author.find(author_id)</tt>)
      # * <tt>Post#author=(author)</tt> (similar to <tt>post.author_id = author.id</tt>)
      # * <tt>Post#build_author</tt> (similar to <tt>post.author = Author.new</tt>)
      # * <tt>Post#create_author</tt> (similar to <tt>post.author = Author.new; post.author.save; post.author</tt>)
      # The declaration can also include an options hash to specialize the behavior of the association.
      #
      # === Options
      #
      # [:class_name]
      #   Specify the class name of the association. Use it only if that name can't be inferred
      #   from the association name. So <tt>has_one :author</tt> will by default be linked to the Author class, but
      #   if the real class name is Person, you'll have to specify it with this option.
      # [:conditions]
      #   Specify the conditions that the associated object must meet in order to be included as a +WHERE+
      #   SQL fragment, such as <tt>authorized = 1</tt>.
      # [:select]
      #   By default, this is <tt>*</tt> as in <tt>SELECT * FROM</tt>, but can be changed
      #   if, for example, you want to do a join but not include the joined columns. Do not
      #   forget to include the primary and foreign keys, otherwise it will raise an error.
      # [:foreign_key]
      #   Specify the foreign key used for the association. By default this is guessed to be the name
      #   of the association with an "_id" suffix. So a class that defines a <tt>belongs_to :person</tt>
      #   association will use "person_id" as the default <tt>:foreign_key</tt>. Similarly,
      #   <tt>belongs_to :favorite_person, :class_name => "Person"</tt> will use a foreign key
      #   of "favorite_person_id".
      # [:primary_key]
      #   Specify the method that returns the primary key of associated object used for the association.
      #   By default this is id.
      # [:dependent]
      #   If set to <tt>:destroy</tt>, the associated object is destroyed when this object is. If set to
      #   <tt>:delete</tt>, the associated object is deleted *without* calling its destroy method.
      #   This option should not be specified when <tt>belongs_to</tt> is used in conjunction with
      #   a <tt>has_many</tt> relationship on another class because of the potential to leave
      #   orphaned records behind.
      # [:counter_cache]
      #   Caches the number of belonging objects on the associate class through the use of +increment_counter+
      #   and +decrement_counter+. The counter cache is incremented when an object of this
      #   class is created and decremented when it's destroyed. This requires that a column
      #   named <tt>#{table_name}_count</tt> (such as +comments_count+ for a belonging Comment class)
      #   is used on the associate class (such as a Post class). You can also specify a custom counter
      #   cache column by providing a column name instead of a +true+/+false+ value to this
      #   option (e.g., <tt>:counter_cache => :my_custom_counter</tt>.)
      #   Note: Specifying a counter cache will add it to that model's list of readonly attributes
      #   using +attr_readonly+.
      # [:include]
      #   Specify second-order associations that should be eager loaded when this object is loaded.
      # [:polymorphic]
      #   Specify this association is a polymorphic association by passing +true+.
      #   Note: If you've enabled the counter cache, then you may want to add the counter cache attribute
      #   to the +attr_readonly+ list in the associated classes (e.g. <tt>class Post; attr_readonly :comments_count; end</tt>).
      # [:readonly]
      #   If true, the associated object is readonly through the association.
      # [:validate]
      #   If +false+, don't validate the associated objects when saving the parent object. +false+ by default.
      # [:autosave]
      #   If true, always save the associated object or destroy it if marked for destruction, when
      #   saving the parent object.
      #   If false, never save or destroy the associated object.
      #   By default, only save the associated object if it's a new record.
      # [:touch]
      #   If true, the associated object will be touched (the updated_at/on attributes set to now)
      #   when this record is either saved or destroyed. If you specify a symbol, that attribute
      #   will be updated with the current time instead of the updated_at/on attribute.
      # [:inverse_of]
      #   Specifies the name of the <tt>has_one</tt> or <tt>has_many</tt> association on the associated
      #   object that is the inverse of this <tt>belongs_to</tt> association.  Does not work in
      #   combination with the <tt>:polymorphic</tt> options.
      #   See ActiveRecord::Associations::ClassMethods's overview on Bi-directional associations for more detail.
      #
      # Option examples:
      #   belongs_to :firm, :foreign_key => "client_of"
      #   belongs_to :person, :primary_key => "name", :foreign_key => "person_name"
      #   belongs_to :author, :class_name => "Person", :foreign_key => "author_id"
      #   belongs_to :valid_coupon, :class_name => "Coupon", :foreign_key => "coupon_id",
      #              :conditions => 'discounts > #{payments_count}'
      #   belongs_to :attachable, :polymorphic => true
      #   belongs_to :project, :readonly => true
      #   belongs_to :post, :counter_cache => true
      #   belongs_to :company, :touch => true
      #   belongs_to :company, :touch => :employees_last_updated_at
      def belongs_to(association_id, options = {})
        reflection = create_belongs_to_reflection(association_id, options)

        if reflection.options[:polymorphic]
          association_accessor_methods(reflection, BelongsToPolymorphicAssociation)
        else
          association_accessor_methods(reflection, BelongsToAssociation)
          association_constructor_method(:build,  reflection, BelongsToAssociation)
          association_constructor_method(:create, reflection, BelongsToAssociation)
        end

        add_counter_cache_callbacks(reflection)          if options[:counter_cache]
        add_touch_callbacks(reflection, options[:touch]) if options[:touch]

        configure_dependency_for_belongs_to(reflection)
      end

      # Specifies a many-to-many relationship with another class. This associates two classes via an
      # intermediate join table.  Unless the join table is explicitly specified as an option, it is
      # guessed using the lexical order of the class names. So a join between Developer and Project
      # will give the default join table name of "developers_projects" because "D" outranks "P".
      # Note that this precedence is calculated using the <tt><</tt> operator for String.  This
      # means that if the strings are of different lengths, and the strings are equal when compared
      # up to the shortest length, then the longer string is considered of higher
      # lexical precedence than the shorter one.  For example, one would expect the tables "paper_boxes" and "papers"
      # to generate a join table name of "papers_paper_boxes" because of the length of the name "paper_boxes",
      # but it in fact generates a join table name of "paper_boxes_papers".  Be aware of this caveat, and use the
      # custom <tt>:join_table</tt> option if you need to.
      #
      # The join table should not have a primary key or a model associated with it. You must manually generate the
      # join table with a migration such as this:
      #
      #   class CreateDevelopersProjectsJoinTable < ActiveRecord::Migration
      #     def self.up
      #       create_table :developers_projects, :id => false do |t|
      #         t.integer :developer_id
      #         t.integer :project_id
      #       end
      #     end
      #
      #     def self.down
      #       drop_table :developers_projects
      #     end
      #   end
      #
      # Deprecated: Any additional fields added to the join table will be placed as attributes when
      # pulling records out through +has_and_belongs_to_many+ associations. Records returned from join
      # tables with additional attributes will be marked as readonly (because we can't save changes
      # to the additional attributes). It's strongly recommended that you upgrade any
      # associations with attributes to a real join model (see introduction).
      #
      # Adds the following methods for retrieval and query:
      #
      # [collection(force_reload = false)]
      #   Returns an array of all the associated objects.
      #   An empty array is returned if none are found.
      # [collection<<(object, ...)]
      #   Adds one or more objects to the collection by creating associations in the join table
      #   (<tt>collection.push</tt> and <tt>collection.concat</tt> are aliases to this method).
      #   Note that this operation instantly fires update sql without waiting for the save or update call on the
      #   parent object.
      # [collection.delete(object, ...)]
      #   Removes one or more objects from the collection by removing their associations from the join table.
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
      #   Uses the same rules as ActiveRecord::Base.find.
      # [collection.exists?(...)]
      #   Checks whether an associated object with the given conditions exists.
      #   Uses the same rules as ActiveRecord::Base.exists?.
      # [collection.build(attributes = {})]
      #   Returns a new object of the collection type that has been instantiated
      #   with +attributes+ and linked to this object through the join table, but has not yet been saved.
      # [collection.create(attributes = {})]
      #   Returns a new object of the collection type that has been instantiated
      #   with +attributes+, linked to this object through the join table, and that has already been
      #   saved (if it passed the validation).
      #
      # (+collection+ is replaced with the symbol passed as the first argument, so
      # <tt>has_and_belongs_to_many :categories</tt> would add among others <tt>categories.empty?</tt>.)
      #
      # === Example
      #
      # A Developer class declares <tt>has_and_belongs_to_many :projects</tt>, which will add:
      # * <tt>Developer#projects</tt>
      # * <tt>Developer#projects<<</tt>
      # * <tt>Developer#projects.delete</tt>
      # * <tt>Developer#projects=</tt>
      # * <tt>Developer#project_ids</tt>
      # * <tt>Developer#project_ids=</tt>
      # * <tt>Developer#projects.clear</tt>
      # * <tt>Developer#projects.empty?</tt>
      # * <tt>Developer#projects.size</tt>
      # * <tt>Developer#projects.find(id)</tt>
      # * <tt>Developer#projects.exists?(...)</tt>
      # * <tt>Developer#projects.build</tt> (similar to <tt>Project.new("project_id" => id)</tt>)
      # * <tt>Developer#projects.create</tt> (similar to <tt>c = Project.new("project_id" => id); c.save; c</tt>)
      # The declaration may include an options hash to specialize the behavior of the association.
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
      #   MUST be declared underneath any +has_and_belongs_to_many+ declaration in order to work.
      # [:foreign_key]
      #   Specify the foreign key used for the association. By default this is guessed to be the name
      #   of this class in lower-case and "_id" suffixed. So a Person class that makes
      #   a +has_and_belongs_to_many+ association to Project will use "person_id" as the
      #   default <tt>:foreign_key</tt>.
      # [:association_foreign_key]
      #   Specify the foreign key used for the association on the receiving side of the association.
      #   By default this is guessed to be the name of the associated class in lower-case and "_id" suffixed.
      #   So if a Person class makes a +has_and_belongs_to_many+ association to Project,
      #   the association will use "project_id" as the default <tt>:association_foreign_key</tt>.
      # [:conditions]
      #   Specify the conditions that the associated object must meet in order to be included as a +WHERE+
      #   SQL fragment, such as <tt>authorized = 1</tt>.  Record creations from the association are
      #   scoped if a hash is used.
      #   <tt>has_many :posts, :conditions => {:published => true}</tt> will create published posts with <tt>@blog.posts.create</tt>
      #   or <tt>@blog.posts.build</tt>.
      # [:order]
      #   Specify the order in which the associated objects are returned as an <tt>ORDER BY</tt> SQL fragment,
      #   such as <tt>last_name, first_name DESC</tt>
      # [:uniq]
      #   If true, duplicate associated objects will be ignored by accessors and query methods.
      # [:finder_sql]
      #   Overwrite the default generated SQL statement used to fetch the association with a manual statement
      # [:counter_sql]
      #   Specify a complete SQL statement to fetch the size of the association. If <tt>:finder_sql</tt> is
      #   specified but not <tt>:counter_sql</tt>, <tt>:counter_sql</tt> will be generated by
      #   replacing <tt>SELECT ... FROM</tt> with <tt>SELECT COUNT(*) FROM</tt>.
      # [:delete_sql]
      #   Overwrite the default generated SQL statement used to remove links between the associated
      #   classes with a manual statement.
      # [:insert_sql]
      #   Overwrite the default generated SQL statement used to add links between the associated classes
      #   with a manual statement.
      # [:extend]
      #   Anonymous module for extending the proxy, see "Association extensions".
      # [:include]
      #   Specify second-order associations that should be eager loaded when the collection is loaded.
      # [:group]
      #   An attribute name by which the result should be grouped. Uses the <tt>GROUP BY</tt> SQL-clause.
      # [:having]
      #   Combined with +:group+ this can be used to filter the records that a <tt>GROUP BY</tt> returns.
      #   Uses the <tt>HAVING</tt> SQL-clause.
      # [:limit]
      #   An integer determining the limit on the number of rows that should be returned.
      # [:offset]
      #   An integer determining the offset from where the rows should be fetched. So at 5,
      #   it would skip the first 4 rows.
      # [:select]
      #   By default, this is <tt>*</tt> as in <tt>SELECT * FROM</tt>, but can be changed if, for example,
      #   you want to do a join but not include the joined columns. Do not forget to include the primary
      #   and foreign keys, otherwise it will raise an error.
      # [:readonly]
      #   If true, all the associated objects are readonly through the association.
      # [:validate]
      #   If +false+, don't validate the associated objects when saving the parent object. +true+ by default.
      # [:autosave]
      #   If true, always save the associated objects or destroy them if marked for destruction, when
      #   saving the parent object.
      #   If false, never save or destroy the associated objects.
      #   By default, only save associated objects that are new records.
      #
      # Option examples:
      #   has_and_belongs_to_many :projects
      #   has_and_belongs_to_many :projects, :include => [ :milestones, :manager ]
      #   has_and_belongs_to_many :nations, :class_name => "Country"
      #   has_and_belongs_to_many :categories, :join_table => "prods_cats"
      #   has_and_belongs_to_many :categories, :readonly => true
      #   has_and_belongs_to_many :active_projects, :join_table => 'developers_projects', :delete_sql =>
      #   'DELETE FROM developers_projects WHERE active=1 AND developer_id = #{id} AND project_id = #{record.id}'
      def has_and_belongs_to_many(association_id, options = {}, &extension)
        reflection = create_has_and_belongs_to_many_reflection(association_id, options, &extension)
        collection_accessor_methods(reflection, HasAndBelongsToManyAssociation)

        configure_after_destroy_method_for_has_and_belongs_to_many(reflection)

        add_association_callbacks(reflection.name, options)
      end

      private
        # Generates a join table name from two provided table names.
        # The names in the join table names end up in lexicographic order.
        #
        #   join_table_name("members", "clubs")         # => "clubs_members"
        #   join_table_name("members", "special_clubs") # => "members_special_clubs"
        def join_table_name(first_table_name, second_table_name)
          if first_table_name < second_table_name
            join_table = "#{first_table_name}_#{second_table_name}"
          else
            join_table = "#{second_table_name}_#{first_table_name}"
          end

          table_name_prefix + join_table + table_name_suffix
        end

        def association_accessor_methods(reflection, association_proxy_class)
          redefine_method(reflection.name) do |*params|
            force_reload = params.first unless params.empty?
            association = association_instance_get(reflection.name)

            if association.nil? || force_reload
              association = association_proxy_class.new(self, reflection)
              retval = force_reload ? reflection.klass.uncached { association.reload } : association.reload
              if retval.nil? and association_proxy_class == BelongsToAssociation
                association_instance_set(reflection.name, nil)
                return nil
              end
              association_instance_set(reflection.name, association)
            end

            association.target.nil? ? nil : association
          end

          redefine_method("loaded_#{reflection.name}?") do
            association = association_instance_get(reflection.name)
            association && association.loaded?
          end

          redefine_method("#{reflection.name}=") do |new_value|
            association = association_instance_get(reflection.name)

            if association.nil? || association.target != new_value
              association = association_proxy_class.new(self, reflection)
            end

            association.replace(new_value)
            association_instance_set(reflection.name, new_value.nil? ? nil : association)
          end

          redefine_method("set_#{reflection.name}_target") do |target|
            return if target.nil? and association_proxy_class == BelongsToAssociation
            association = association_proxy_class.new(self, reflection)
            association.target = target
            association_instance_set(reflection.name, association)
          end
        end

        def collection_reader_method(reflection, association_proxy_class)
          redefine_method(reflection.name) do |*params|
            force_reload = params.first unless params.empty?
            association = association_instance_get(reflection.name)

            unless association
              association = association_proxy_class.new(self, reflection)
              association_instance_set(reflection.name, association)
            end

            reflection.klass.uncached { association.reload } if force_reload

            association
          end

          redefine_method("#{reflection.name.to_s.singularize}_ids") do
            if send(reflection.name).loaded? || reflection.options[:finder_sql]
              send(reflection.name).map { |r| r.id }
            else
              if reflection.through_reflection && reflection.source_reflection.belongs_to?
                through = reflection.through_reflection
                primary_key = reflection.source_reflection.primary_key_name
                send(through.name).select("DISTINCT #{through.quoted_table_name}.#{primary_key}").map! { |r| r.send(primary_key) }
              else
                send(reflection.name).select("#{reflection.quoted_table_name}.#{reflection.klass.primary_key}").except(:includes).map! { |r| r.id }
              end
            end
          end

        end

        def collection_accessor_methods(reflection, association_proxy_class, writer = true)
          collection_reader_method(reflection, association_proxy_class)

          if writer
            redefine_method("#{reflection.name}=") do |new_value|
              # Loads proxy class instance (defined in collection_reader_method) if not already loaded
              association = send(reflection.name)
              association.replace(new_value)
              association
            end

            redefine_method("#{reflection.name.to_s.singularize}_ids=") do |new_value|
              pk_column = reflection.primary_key_column
              ids = (new_value || []).reject { |nid| nid.blank? }
              ids.map!{ |i| pk_column.type_cast(i) }
              send("#{reflection.name}=", reflection.klass.find(ids).index_by{ |r| r.id }.values_at(*ids))
            end
          end
        end

        def association_constructor_method(constructor, reflection, association_proxy_class)
          redefine_method("#{constructor}_#{reflection.name}") do |*params|
            attributees      = params.first unless params.empty?
            replace_existing = params[1].nil? ? true : params[1]
            association      = association_instance_get(reflection.name)

            unless association
              association = association_proxy_class.new(self, reflection)
              association_instance_set(reflection.name, association)
            end

            if association_proxy_class == HasOneAssociation
              association.send(constructor, attributees, replace_existing)
            else
              association.send(constructor, attributees)
            end
          end
        end

        def add_counter_cache_callbacks(reflection)
          cache_column = reflection.counter_cache_column

          method_name = "belongs_to_counter_cache_after_create_for_#{reflection.name}".to_sym
          define_method(method_name) do
            association = send(reflection.name)
            association.class.increment_counter(cache_column, association.id) unless association.nil?
          end
          after_create(method_name)

          method_name = "belongs_to_counter_cache_before_destroy_for_#{reflection.name}".to_sym
          define_method(method_name) do
            association = send(reflection.name)
            association.class.decrement_counter(cache_column, association.id) unless association.nil?
          end
          before_destroy(method_name)

          module_eval(
            "#{reflection.class_name}.send(:attr_readonly,\"#{cache_column}\".intern) if defined?(#{reflection.class_name}) && #{reflection.class_name}.respond_to?(:attr_readonly)", __FILE__, __LINE__
          )
        end

        def add_touch_callbacks(reflection, touch_attribute)
          method_name = :"belongs_to_touch_after_save_or_destroy_for_#{reflection.name}"
          redefine_method(method_name) do
            association = send(reflection.name)

            if touch_attribute == true
              association.touch unless association.nil?
            else
              association.touch(touch_attribute) unless association.nil?
            end
          end
          after_save(method_name)
          after_touch(method_name)
          after_destroy(method_name)
        end

        # Creates before_destroy callback methods that nullify, delete or destroy
        # has_many associated objects, according to the defined :dependent rule.
        # If the association is marked as :dependent => :restrict, create a callback
        # that prevents deleting entirely.
        #
        # See HasManyAssociation#delete_records.  Dependent associations
        # delete children, otherwise foreign key is set to NULL.
        # See HasManyAssociation#delete_records. Dependent associations
        # delete children if the option is set to :destroy or :delete_all, set the
        # foreign key to NULL if the option is set to :nullify, and do not touch the
        # child records if the option is set to :restrict.
        #
        # The +extra_conditions+ parameter, which is not used within the main
        # Active Record codebase, is meant to allow plugins to define extra
        # finder conditions.
        def configure_dependency_for_has_many(reflection, extra_conditions = nil)
          if reflection.options.include?(:dependent)
            case reflection.options[:dependent]
              when :destroy
                method_name = "has_many_dependent_destroy_for_#{reflection.name}".to_sym
                define_method(method_name) do
                  send(reflection.name).each do |o|
                    # No point in executing the counter update since we're going to destroy the parent anyway
                    counter_method = ('belongs_to_counter_cache_before_destroy_for_' + self.class.name.downcase).to_sym
                    if(o.respond_to? counter_method) then
                      class << o
                        self
                      end.send(:define_method, counter_method, Proc.new {})
                    end
                    o.destroy
                  end
                end
                before_destroy method_name
              when :delete_all
                before_destroy do |record|
                  self.class.send(:delete_all_has_many_dependencies,
                  record,
                  reflection.name,
                  reflection.klass,
                  reflection.dependent_conditions(record, self.class, extra_conditions))
                end
              when :nullify
                before_destroy do |record|
                  self.class.send(:nullify_has_many_dependencies,
                  record,
                  reflection.name,
                  reflection.klass,
                  reflection.primary_key_name,
                  reflection.dependent_conditions(record, self.class, extra_conditions))
                end
              when :restrict
                method_name = "has_many_dependent_restrict_for_#{reflection.name}".to_sym
                define_method(method_name) do
                  unless send(reflection.name).empty?
                    raise DeleteRestrictionError.new(reflection)
                  end
                end
                before_destroy method_name
              else
                raise ArgumentError, "The :dependent option expects either :destroy, :delete_all, :nullify or :restrict (#{reflection.options[:dependent].inspect})"
            end
          end
        end

        # Creates before_destroy callback methods that nullify, delete or destroy
        # has_one associated objects, according to the defined :dependent rule.
        # If the association is marked as :dependent => :restrict, create a callback
        # that prevents deleting entirely.
        def configure_dependency_for_has_one(reflection)
          if reflection.options.include?(:dependent)
            name = reflection.options[:dependent]
            method_name = :"has_one_dependent_#{name}_for_#{reflection.name}"

            case name
              when :destroy, :delete
                class_eval <<-eoruby, __FILE__, __LINE__ + 1
                  def #{method_name}
                    association = #{reflection.name}
                    association.#{name} if association
                  end
                eoruby
              when :nullify
                class_eval <<-eoruby, __FILE__, __LINE__ + 1
                  def #{method_name}
                    association = #{reflection.name}
                    association.update_attribute(#{reflection.primary_key_name.inspect}, nil) if association
                  end
                eoruby
              when :restrict
                method_name = "has_one_dependent_restrict_for_#{reflection.name}".to_sym
                define_method(method_name) do
                  unless send(reflection.name).nil?
                    raise DeleteRestrictionError.new(reflection)
                  end
                end
                before_destroy method_name
              else
                raise ArgumentError, "The :dependent option expects either :destroy, :delete, :nullify or :restrict (#{reflection.options[:dependent].inspect})"
            end

            before_destroy method_name
          end
        end

        def configure_dependency_for_belongs_to(reflection)
          if reflection.options.include?(:dependent)
            name = reflection.options[:dependent]

            unless [:destroy, :delete].include?(name)
              raise ArgumentError, "The :dependent option expects either :destroy or :delete (#{reflection.options[:dependent].inspect})"
            end

            method_name = :"belongs_to_dependent_#{name}_for_#{reflection.name}"
            class_eval <<-eoruby, __FILE__, __LINE__ + 1
              def #{method_name}
                association = #{reflection.name}
                association.#{name} if association
              end
            eoruby
            after_destroy method_name
          end
        end

        def configure_after_destroy_method_for_has_and_belongs_to_many(reflection)
          method_name = :"has_and_belongs_to_many_after_destroy_for_#{reflection.name}"
          class_eval <<-eoruby, __FILE__, __LINE__ + 1
            def #{method_name}
              association = #{reflection.name}
              association.delete_all if association
            end
          eoruby
          after_destroy method_name
        end

        def delete_all_has_many_dependencies(record, reflection_name, association_class, dependent_conditions)
          association_class.delete_all(dependent_conditions)
        end

        def nullify_has_many_dependencies(record, reflection_name, association_class, primary_key_name, dependent_conditions)
          association_class.update_all("#{primary_key_name} = NULL", dependent_conditions)
        end

        mattr_accessor :valid_keys_for_has_many_association
        @@valid_keys_for_has_many_association = [
          :class_name, :table_name, :foreign_key, :primary_key,
          :dependent,
          :select, :conditions, :include, :order, :group, :having, :limit, :offset,
          :as, :through, :source, :source_type,
          :uniq,
          :finder_sql, :counter_sql,
          :before_add, :after_add, :before_remove, :after_remove,
          :extend, :readonly,
          :validate, :inverse_of
        ]

        def create_has_many_reflection(association_id, options, &extension)
          options.assert_valid_keys(valid_keys_for_has_many_association)
          options[:extend] = create_extension_modules(association_id, extension, options[:extend])

          create_reflection(:has_many, association_id, options, self)
        end

        mattr_accessor :valid_keys_for_has_one_association
        @@valid_keys_for_has_one_association = [
          :class_name, :foreign_key, :remote, :select, :conditions, :order,
          :include, :dependent, :counter_cache, :extend, :as, :readonly,
          :validate, :primary_key, :inverse_of
        ]

        def create_has_one_reflection(association_id, options)
          options.assert_valid_keys(valid_keys_for_has_one_association)
          create_reflection(:has_one, association_id, options, self)
        end

        def create_has_one_through_reflection(association_id, options)
          options.assert_valid_keys(
            :class_name, :foreign_key, :remote, :select, :conditions, :order, :include, :dependent, :counter_cache, :extend, :as, :through, :source, :source_type, :validate
          )
          create_reflection(:has_one, association_id, options, self)
        end

        mattr_accessor :valid_keys_for_belongs_to_association
        @@valid_keys_for_belongs_to_association = [
          :class_name, :primary_key, :foreign_key, :foreign_type, :remote, :select, :conditions,
          :include, :dependent, :counter_cache, :extend, :polymorphic, :readonly,
          :validate, :touch, :inverse_of
        ]

        def create_belongs_to_reflection(association_id, options)
          options.assert_valid_keys(valid_keys_for_belongs_to_association)
          reflection = create_reflection(:belongs_to, association_id, options, self)

          if options[:polymorphic]
            reflection.options[:foreign_type] ||= reflection.class_name.underscore + "_type"
          end

          reflection
        end

        mattr_accessor :valid_keys_for_has_and_belongs_to_many_association
        @@valid_keys_for_has_and_belongs_to_many_association = [
          :class_name, :table_name, :join_table, :foreign_key, :association_foreign_key,
          :select, :conditions, :include, :order, :group, :having, :limit, :offset,
          :uniq,
          :finder_sql, :counter_sql, :delete_sql, :insert_sql,
          :before_add, :after_add, :before_remove, :after_remove,
          :extend, :readonly,
          :validate
        ]

        def create_has_and_belongs_to_many_reflection(association_id, options, &extension)
          options.assert_valid_keys(valid_keys_for_has_and_belongs_to_many_association)
          options[:extend] = create_extension_modules(association_id, extension, options[:extend])

          reflection = create_reflection(:has_and_belongs_to_many, association_id, options, self)

          if reflection.association_foreign_key == reflection.primary_key_name
            raise HasAndBelongsToManyAssociationForeignKeyNeeded.new(reflection)
          end

          reflection.options[:join_table] ||= join_table_name(undecorated_table_name(self.to_s), undecorated_table_name(reflection.class_name))
          if connection.supports_primary_key? && (connection.primary_key(reflection.options[:join_table]) rescue false)
             raise HasAndBelongsToManyAssociationWithPrimaryKeyError.new(reflection)
          end

          reflection
        end

        def add_association_callbacks(association_name, options)
          callbacks = %w(before_add after_add before_remove after_remove)
          callbacks.each do |callback_name|
            full_callback_name = "#{callback_name}_for_#{association_name}"
            defined_callbacks = options[callback_name.to_sym]
            if options.has_key?(callback_name.to_sym)
              class_inheritable_reader full_callback_name.to_sym
              write_inheritable_attribute(full_callback_name.to_sym, [defined_callbacks].flatten)
            else
              write_inheritable_attribute(full_callback_name.to_sym, [])
            end
          end
        end

        def create_extension_modules(association_id, block_extension, extensions)
          if block_extension
            extension_module_name = "#{self.to_s.demodulize}#{association_id.to_s.camelize}AssociationExtension"

            silence_warnings do
              self.parent.const_set(extension_module_name, Module.new(&block_extension))
            end
            Array.wrap(extensions).push("#{self.parent}::#{extension_module_name}".constantize)
          else
            Array.wrap(extensions)
          end
        end

        class JoinDependency # :nodoc:
          attr_reader :joins, :reflections, :table_aliases

          def initialize(base, associations, joins)
            @joins                 = [JoinBase.new(base, joins)]
            @associations          = {}
            @reflections           = []
            @base_records_hash     = {}
            @base_records_in_order = []
            @table_aliases         = Hash.new { |aliases, table| aliases[table] = 0 }
            @table_aliases[base.table_name] = 1
            build(associations)
          end

          def graft(*associations)
            associations.each do |association|
              join_associations.detect {|a| association == a} ||
              build(association.reflection.name, association.find_parent_in(self) || join_base, association.join_type)
            end
            self
          end

          def join_associations
            @joins[1..-1].to_a
          end

          def join_base
            @joins[0]
          end

          def count_aliases_from_table_joins(name)
            # quoted_name should be downcased as some database adapters (Oracle) return quoted name in uppercase
            quoted_name = join_base.active_record.connection.quote_table_name(name.downcase).downcase
            join_sql = join_base.table_joins.to_s.downcase
            join_sql.blank? ? 0 :
              # Table names
              join_sql.scan(/join(?:\s+\w+)?\s+#{quoted_name}\son/).size +
              # Table aliases
              join_sql.scan(/join(?:\s+\w+)?\s+\S+\s+#{quoted_name}\son/).size
          end

          def instantiate(rows)
            rows.each_with_index do |row, i|
              primary_id = join_base.record_id(row)
              unless @base_records_hash[primary_id]
                @base_records_in_order << (@base_records_hash[primary_id] = join_base.instantiate(row))
              end
              construct(@base_records_hash[primary_id], @associations, join_associations.dup, row)
            end
            remove_duplicate_results!(join_base.active_record, @base_records_in_order, @associations)
            return @base_records_in_order
          end

          def remove_duplicate_results!(base, records, associations)
            case associations
              when Symbol, String
                reflection = base.reflections[associations]
                remove_uniq_by_reflection(reflection, records)
              when Array
                associations.each do |association|
                  remove_duplicate_results!(base, records, association)
                end
              when Hash
                associations.keys.each do |name|
                  reflection = base.reflections[name]
                  remove_uniq_by_reflection(reflection, records)

                  parent_records = []
                  records.each do |record|
                    if descendant = record.send(reflection.name)
                      if reflection.collection?
                        parent_records.concat descendant.target.uniq
                      else
                        parent_records << descendant
                      end
                    end
                  end

                  remove_duplicate_results!(reflection.klass, parent_records, associations[name]) unless parent_records.empty?
                end
            end
          end

          protected

            def cache_joined_association(association)
              associations = []
              parent = association.parent
              while parent != join_base
                associations.unshift(parent.reflection.name)
                parent = parent.parent
              end
              ref = @associations
              associations.each do |key|
                ref = ref[key]
              end
              ref[association.reflection.name] ||= {}
            end

            def build(associations, parent = nil, join_type = Arel::InnerJoin)
              parent ||= @joins.last
              case associations
                when Symbol, String
                  reflection = parent.reflections[associations.to_s.intern] or
                  raise ConfigurationError, "Association named '#{ associations }' was not found; perhaps you misspelled it?"
                  unless join_association = find_join_association(reflection, parent)
                    @reflections << reflection
                    join_association = build_join_association(reflection, parent)
                    join_association.join_type = join_type
                    @joins << join_association
                    cache_joined_association(join_association)
                  end
                  join_association
                when Array
                  associations.each do |association|
                    build(association, parent, join_type)
                  end
                when Hash
                  associations.keys.sort{|a,b|a.to_s<=>b.to_s}.each do |name|
                    join_association = build(name, parent, join_type)
                    build(associations[name], join_association, join_type)
                  end
                else
                  raise ConfigurationError, associations.inspect
              end
            end

            def find_join_association(name_or_reflection, parent)
              case name_or_reflection
              when Symbol, String
                join_associations.detect {|j| (j.reflection.name == name_or_reflection.to_s.intern) && (j.parent == parent)}
              else
                join_associations.detect {|j| (j.reflection == name_or_reflection) && (j.parent == parent)}
              end
            end

            def remove_uniq_by_reflection(reflection, records)
              if reflection && reflection.collection?
                records.each { |record| record.send(reflection.name).target.uniq! }
              end
            end

            def build_join_association(reflection, parent)
              JoinAssociation.new(reflection, self, parent)
            end

            def construct(parent, associations, joins, row)
              case associations
                when Symbol, String
                  join = joins.detect{|j| j.reflection.name.to_s == associations.to_s && j.parent_table_name == parent.class.table_name }
                  raise(ConfigurationError, "No such association") if join.nil?

                  joins.delete(join)
                  construct_association(parent, join, row)
                when Array
                  associations.each do |association|
                    construct(parent, association, joins, row)
                  end
                when Hash
                  associations.keys.sort{|a,b|a.to_s<=>b.to_s}.each do |name|
                    join = joins.detect{|j| j.reflection.name.to_s == name.to_s && j.parent_table_name == parent.class.table_name }
                    raise(ConfigurationError, "No such association") if join.nil?

                    association = construct_association(parent, join, row)
                    joins.delete(join)
                    construct(association, associations[name], joins, row) if association
                  end
                else
                  raise ConfigurationError, associations.inspect
              end
            end

            def construct_association(record, join, row)
              case join.reflection.macro
                when :has_many, :has_and_belongs_to_many
                  collection = record.send(join.reflection.name)
                  collection.loaded

                  return nil if record.id.to_s != join.parent.record_id(row).to_s or row[join.aliased_primary_key].nil?
                  association = join.instantiate(row)
                  collection.target.push(association)
                  collection.__send__(:set_inverse_instance, association, record)
                when :has_one
                  return if record.id.to_s != join.parent.record_id(row).to_s
                  return if record.instance_variable_defined?("@#{join.reflection.name}")
                  association = join.instantiate(row) unless row[join.aliased_primary_key].nil?
                  set_target_and_inverse(join, association, record)
                when :belongs_to
                  return if record.id.to_s != join.parent.record_id(row).to_s or row[join.aliased_primary_key].nil?
                  association = join.instantiate(row)
                  set_target_and_inverse(join, association, record)
                else
                  raise ConfigurationError, "unknown macro: #{join.reflection.macro}"
              end
              return association
            end

            def set_target_and_inverse(join, association, record)
              association_proxy = record.send("set_#{join.reflection.name}_target", association)
              association_proxy.__send__(:set_inverse_instance, association, record)
            end

          class JoinBase # :nodoc:
            attr_reader :active_record, :table_joins
            delegate    :table_name, :column_names, :primary_key, :reflections, :sanitize_sql, :arel_engine, :to => :active_record

            def initialize(active_record, joins = nil)
              @active_record = active_record
              @cached_record = {}
              @table_joins   = joins
            end

            def ==(other)
              other.class == self.class &&
              other.active_record == active_record
            end

            def aliased_prefix
              "t0"
            end

            def aliased_primary_key
              "#{aliased_prefix}_r0"
            end

            def aliased_table_name
              active_record.table_name
            end

            def column_names_with_alias
              unless defined?(@column_names_with_alias)
                @column_names_with_alias = []

                ([primary_key] + (column_names - [primary_key])).each_with_index do |column_name, i|
                  @column_names_with_alias << [column_name, "#{aliased_prefix}_r#{i}"]
                end
              end

              @column_names_with_alias
            end

            def extract_record(row)
              Hash[column_names_with_alias.map{|cn, an| [cn, row[an]]}]
            end

            def record_id(row)
              row[aliased_primary_key]
            end

            def instantiate(row)
              @cached_record[record_id(row)] ||= active_record.send(:instantiate, extract_record(row))
            end
          end

          class JoinAssociation < JoinBase # :nodoc:
            attr_reader :reflection, :parent, :aliased_table_name, :aliased_prefix, :aliased_join_table_name, :parent_table_name
            # What type of join will be generated, either Arel::InnerJoin (default) or Arel::OuterJoin
            attr_accessor :join_type
            delegate    :options, :klass, :through_reflection, :source_reflection, :to => :reflection

            def initialize(reflection, join_dependency, parent = nil)
              reflection.check_validity!
              if reflection.options[:polymorphic]
                raise EagerLoadPolymorphicError.new(reflection)
              end

              super(reflection.klass)
              @join_dependency    = join_dependency
              @parent             = parent
              @reflection         = reflection
              @aliased_prefix     = "t#{ join_dependency.joins.size }"
              @parent_table_name  = parent.active_record.table_name
              @aliased_table_name = aliased_table_name_for(table_name)
              @join               = nil
              @join_type          = Arel::InnerJoin

              if reflection.macro == :has_and_belongs_to_many
                @aliased_join_table_name = aliased_table_name_for(reflection.options[:join_table], "_join")
              end

              if [:has_many, :has_one].include?(reflection.macro) && reflection.options[:through]
                @aliased_join_table_name = aliased_table_name_for(reflection.through_reflection.klass.table_name, "_join")
              end
            end

            def ==(other)
              other.class == self.class &&
              other.reflection == reflection &&
              other.parent == parent
            end

            def find_parent_in(other_join_dependency)
              other_join_dependency.joins.detect do |join|
                self.parent == join
              end
            end

            def association_join
              return @join if @join

              aliased_table = Arel::Table.new(table_name, :as      => @aliased_table_name,
                                                          :engine  => arel_engine,
                                                          :columns => klass.columns)

              parent_table = Arel::Table.new(parent.table_name, :as      => parent.aliased_table_name,
                                                                :engine  => arel_engine,
                                                                :columns => parent.active_record.columns)

              @join = case reflection.macro
              when :has_and_belongs_to_many
                join_table = Arel::Table.new(options[:join_table], :as => aliased_join_table_name, :engine => arel_engine)
                fk = options[:foreign_key] || reflection.active_record.to_s.foreign_key
                klass_fk = options[:association_foreign_key] || klass.to_s.foreign_key

                [
                  join_table[fk].eq(parent_table[reflection.active_record.primary_key]),
                  aliased_table[klass.primary_key].eq(join_table[klass_fk])
                ]
              when :has_many, :has_one
                if reflection.options[:through]
                  join_table = Arel::Table.new(through_reflection.klass.table_name, :as => aliased_join_table_name, :engine => arel_engine)
                  jt_as_extra = jt_source_extra = jt_sti_extra = nil
                  first_key = second_key = as_extra = nil

                  if through_reflection.macro == :belongs_to
                    jt_primary_key = through_reflection.primary_key_name
                    jt_foreign_key = through_reflection.association_primary_key
                  else
                    jt_primary_key = through_reflection.active_record_primary_key
                    jt_foreign_key = through_reflection.primary_key_name

                    if through_reflection.options[:as] # has_many :through against a polymorphic join
                      jt_as_extra = join_table[through_reflection.options[:as].to_s + '_type'].eq(parent.active_record.base_class.name)
                    end
                  end

                  case source_reflection.macro
                  when :has_many, :has_one
                    if source_reflection.options[:as]
                      first_key   = "#{source_reflection.options[:as]}_id"
                      second_key  = options[:foreign_key] || primary_key
                      as_extra    = aliased_table["#{source_reflection.options[:as]}_type"].eq(source_reflection.active_record.base_class.name)
                    else
                      first_key   = through_reflection.klass.base_class.to_s.foreign_key
                      second_key  = options[:foreign_key] || primary_key
                    end

                    unless through_reflection.klass.descends_from_active_record?
                      jt_sti_extra = join_table[through_reflection.active_record.inheritance_column].eq(through_reflection.klass.sti_name)
                    end
                  when :belongs_to
                    first_key = primary_key
                    if reflection.options[:source_type]
                      second_key = source_reflection.association_foreign_key
                      jt_source_extra = join_table[reflection.source_reflection.options[:foreign_type]].eq(reflection.options[:source_type])
                    else
                      second_key = source_reflection.primary_key_name
                    end
                  end

                  [
                    [parent_table[jt_primary_key].eq(join_table[jt_foreign_key]), jt_as_extra, jt_source_extra, jt_sti_extra].reject{|x| x.blank? },
                    [aliased_table[first_key].eq(join_table[second_key]), as_extra].reject{ |x| x.blank? }
                  ]
                elsif reflection.options[:as]
                  id_rel = aliased_table["#{reflection.options[:as]}_id"].eq(parent_table[parent.primary_key])
                  type_rel = aliased_table["#{reflection.options[:as]}_type"].eq(parent.active_record.base_class.name)
                  [id_rel, type_rel]
                else
                  foreign_key = options[:foreign_key] || reflection.active_record.name.foreign_key
                  [aliased_table[foreign_key].eq(parent_table[reflection.options[:primary_key] || parent.primary_key])]
                end
              when :belongs_to
                [aliased_table[options[:primary_key] || reflection.klass.primary_key].eq(parent_table[options[:foreign_key] || reflection.primary_key_name])]
              end

              unless klass.descends_from_active_record?
                sti_column = aliased_table[klass.inheritance_column]
                sti_condition = sti_column.eq(klass.sti_name)
                klass.descendants.each {|subclass| sti_condition = sti_condition.or(sti_column.eq(subclass.sti_name)) }

                @join << sti_condition
              end

              [through_reflection, reflection].each do |ref|
                if ref && ref.options[:conditions]
                  @join << process_conditions(ref.options[:conditions], aliased_table_name)
                end
              end

              @join
            end

            def relation
              aliased = Arel::Table.new(table_name, :as => @aliased_table_name,
                                                    :engine => arel_engine,
                                                    :columns => klass.columns)

              if reflection.macro == :has_and_belongs_to_many
                [Arel::Table.new(options[:join_table], :as => aliased_join_table_name, :engine => arel_engine), aliased]
              elsif reflection.options[:through]
                [Arel::Table.new(through_reflection.klass.table_name, :as => aliased_join_table_name, :engine => arel_engine), aliased]
              else
                aliased
              end
            end

            def join_relation(joining_relation)
              self.join_type = Arel::OuterJoin
              joining_relation.joins(self)
            end

            protected

              def aliased_table_name_for(name, suffix = nil)
                if @join_dependency.table_aliases[name].zero?
                  @join_dependency.table_aliases[name] = @join_dependency.count_aliases_from_table_joins(name)
                end

                if !@join_dependency.table_aliases[name].zero? # We need an alias
                  name = active_record.connection.table_alias_for "#{pluralize(reflection.name)}_#{parent_table_name}#{suffix}"
                  @join_dependency.table_aliases[name] += 1
                  if @join_dependency.table_aliases[name] == 1 # First time we've seen this name
                    # Also need to count the aliases from the table_aliases to avoid incorrect count
                    @join_dependency.table_aliases[name] += @join_dependency.count_aliases_from_table_joins(name)
                  end
                  table_index = @join_dependency.table_aliases[name]
                  name = name[0..active_record.connection.table_alias_length-3] + "_#{table_index}" if table_index > 1
                else
                  @join_dependency.table_aliases[name] += 1
                end

                name
              end

              def pluralize(table_name)
                ActiveRecord::Base.pluralize_table_names ? table_name.to_s.pluralize : table_name
              end

              def table_alias_for(table_name, table_alias)
                 "#{table_name} #{table_alias if table_name != table_alias}".strip
              end

              def table_name_and_alias
                table_alias_for table_name, @aliased_table_name
              end

              def process_conditions(conditions, table_name)
                sanitized = sanitize_sql(conditions, table_name)

                if sanitized =~ /\#\{.*\}/
                  ActiveSupport::Deprecation.warn(
                    'String-based interpolation of association conditions is deprecated. Please use a ' \
                    'proc instead. So, for example, has_many :older_friends, :conditions => \'age > #{age}\' ' \
                    'should be changed to has_many :older_friends, :conditions => proc { "age > #{age}" }.'
                  )
                  instance_eval("%@#{sanitized.gsub('@', '\@')}@", __FILE__, __LINE__)
                elsif conditions.respond_to?(:to_proc)
                  conditions = sanitize_sql(instance_eval(&conditions), table_name)
                else
                  sanitized
                end
              end
          end
        end
    end
  end
end
