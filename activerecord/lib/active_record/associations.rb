require 'active_record/associations/association_collection'
require 'active_record/associations/has_many_association'
require 'active_record/associations/has_and_belongs_to_many_association'
require 'active_record/deprecated_associations'


unless Object.respond_to?(:require_association)
  Object.send(:define_method, :require_association) { |file_name| ActiveRecord::Base.require_association(file_name) }
end

class Object
  class << self
    # Use const_missing to autoload associations so we don't have to
    # require_association when using single-table inheritance.
    unless respond_to?(:pre_association_const_missing)
      alias_method :pre_association_const_missing, :const_missing

      def const_missing(class_id)
        begin
          require_association(Inflector.underscore(Inflector.demodulize(class_id.to_s)))
          return Object.const_get(class_id) if Object.const_get(class_id).ancestors.include?(ActiveRecord::Base)
        rescue LoadError
          pre_association_const_missing(class_id)
        end
      end
    end
  end
end

module ActiveRecord
  module Associations # :nodoc:
    def self.append_features(base)
      super
      base.extend(ClassMethods)
    end

    # Clears out the association cache 
    def clear_association_cache #:nodoc:
      self.class.reflect_on_all_associations.to_a.each do |assoc|
        instance_variable_set "@#{assoc.name}", nil
      end
    end

    # Associations are a set of macro-like class methods for tying objects together through foreign keys. They express relationships like 
    # "Project has one Project Manager" or "Project belongs to a Portfolio". Each macro adds a number of methods to the class which are 
    # specialized according to the collection or association symbol and the options hash. It works much the same was as Ruby's own attr* 
    # methods. Example:
    #
    #   class Project < ActiveRecord::Base
    #     belongs_to              :portfolio
    #     has_one                 :project_manager 
    #     has_many                :milestones
    #     has_and_belongs_to_many :categories
    #   end
    #
    # The project class now has the following methods (and more) to ease the traversal and manipulation of its relationships:
    # * <tt>Project#portfolio, Project#portfolio=(portfolio), Project#portfolio.nil?, Project#portfolio?(portfolio)</tt>
    # * <tt>Project#project_manager, Project#project_manager=(project_manager), Project#project_manager.nil?,</tt>
    #   <tt>Project#project_manager?(project_manager), Project#build_project_manager, Project#create_project_manager</tt>
    # * <tt>Project#milestones.empty?, Project#milestones.size, Project#milestones, Project#milestones<<(milestone),</tt>
    #   <tt>Project#milestones.delete(milestone), Project#milestones.find(milestone_id), Project#milestones.find_all(conditions),</tt>
    #   <tt>Project#milestones.build, Project#milestones.create</tt>
    # * <tt>Project#categories.empty?, Project#categories.size, Project#categories, Project#categories<<(category1),</tt>
    #   <tt>Project#categories.delete(category1)</tt>
    #
    # == Example
    #
    # link:../examples/associations.png
    #
    # == Is it belongs_to or has_one?
    #
    # Both express a 1-1 relationship, the difference is mostly where to place the foreign key, which goes on the table for the class
    # saying belongs_to. Example:
    #
    #   class Post < ActiveRecord::Base
    #     has_one :author
    #   end
    #
    #   class Author < ActiveRecord::Base
    #     belongs_to :post
    #   end
    #
    # The tables for these classes could look something like:
    #
    #   CREATE TABLE posts (
    #     id int(11) NOT NULL auto_increment,
    #     title varchar default NULL,
    #     PRIMARY KEY  (id)
    #   )
    #
    #   CREATE TABLE authors (
    #     id int(11) NOT NULL auto_increment,
    #     post_id int(11) default NULL,
    #     name varchar default NULL,
    #     PRIMARY KEY  (id)
    #   )
    #
    # == Caching
    #
    # All of the methods are built on a simple caching principle that will keep the result of the last query around unless specifically
    # instructed not to. The cache is even shared across methods to make it even cheaper to use the macro-added methods without 
    # worrying too much about performance at the first go. Example:
    #
    #   project.milestones             # fetches milestones from the database
    #   project.milestones.size        # uses the milestone cache
    #   project.milestones.empty?      # uses the milestone cache
    #   project.milestones(true).size  # fetches milestones from the database
    #   project.milestones             # uses the milestone cache
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
    #       class Company < ActiveRecord::Base; end
    #     end
    #   end
    #
    # When Firm#clients is called, it'll in turn call <tt>MyApplication::Business::Company.find(firm.id)</tt>. If you want to associate
    # with a class in another module scope this can be done by specifying the complete class name, such as:
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
    # == Type safety with ActiveRecord::AssociationTypeMismatch
    #
    # If you attempt to assign an object to an association that doesn't match the inferred or specified <tt>:class_name</tt>, you'll
    # get a ActiveRecord::AssociationTypeMismatch.
    #
    # == Options
    #
    # All of the association macros can be specialized through options which makes more complex cases than the simple and guessable ones
    # possible.
    module ClassMethods
      # Adds the following methods for retrival and query of collections of associated objects.
      # +collection+ is replaced with the symbol passed as the first argument, so 
      # <tt>has_many :clients</tt> would add among others <tt>has_clients?</tt>.
      # * <tt>collection(force_reload = false)</tt> - returns an array of all the associated objects.
      #   An empty array is returned if none are found.
      # * <tt>collection<<(object, ...)</tt> - adds one or more objects to the collection by setting their foreign keys to the collection's primary key.
      # * <tt>collection.delete(object, ...)</tt> - removes one or more objects from the collection by setting their foreign keys to NULL.  This does not destroy the objects.
      # * <tt>collection.clear</tt> - removes every object from the collection. This does not destroy the objects.
      # * <tt>collection.empty?</tt> - returns true if there are no associated objects.
      # * <tt>collection.size</tt> - returns the number of associated objects.
      # * <tt>collection.find(id)</tt> - finds an associated object responding to the +id+ and that
      #   meets the condition that it has to be associated with this object.
      # * <tt>collection.find_all(conditions = nil, orderings = nil, limit = nil, joins = nil)</tt> - finds all associated objects responding 
      #   criterias mentioned (like in the standard find_all) and that meets the condition that it has to be associated with this object.
      # * <tt>collection.build(attributes = {})</tt> - returns a new object of the collection type that has been instantiated
      #   with +attributes+ and linked to this object through a foreign key but has not yet been saved.
      # * <tt>collection.create(attributes = {})</tt> - returns a new object of the collection type that has been instantiated
      #   with +attributes+ and linked to this object through a foreign key and that has already been saved (if it passed the validation).
      #
      # Example: A Firm class declares <tt>has_many :clients</tt>, which will add:
      # * <tt>Firm#clients</tt> (similar to <tt>Clients.find_all "firm_id = #{id}"</tt>)
      # * <tt>Firm#clients<<</tt>
      # * <tt>Firm#clients.delete</tt>
      # * <tt>Firm#clients.clear</tt>
      # * <tt>Firm#clients.empty?</tt> (similar to <tt>firm.clients.size == 0</tt>)
      # * <tt>Firm#clients.size</tt> (similar to <tt>Client.count "firm_id = #{id}"</tt>)
      # * <tt>Firm#clients.find</tt> (similar to <tt>Client.find_on_conditions(id, "firm_id = #{id}")</tt>)
      # * <tt>Firm#clients.find_all</tt> (similar to <tt>Client.find_all "firm_id = #{id}"</tt>)
      # * <tt>Firm#clients.build</tt> (similar to <tt>Client.new("firm_id" => id)</tt>)
      # * <tt>Firm#clients.create</tt> (similar to <tt>c = Client.new("client_id" => id); c.save; c</tt>)
      # The declaration can also include an options hash to specialize the behavior of the association.
      # 
      # Options are:
      # * <tt>:class_name</tt>  - specify the class name of the association. Use it only if that name can't be infered
      #   from the association name. So <tt>has_many :products</tt> will by default be linked to the +Product+ class, but
      #   if the real class name is +SpecialProduct+, you'll have to specify it with this option.
      # * <tt>:conditions</tt>  - specify the conditions that the associated objects must meet in order to be included as a "WHERE"
      #   sql fragment, such as "price > 5 AND name LIKE 'B%'".
      # * <tt>:order</tt>       - specify the order in which the associated objects are returned as a "ORDER BY" sql fragment,
      #   such as "last_name, first_name DESC"
      # * <tt>:foreign_key</tt> - specify the foreign key used for the association. By default this is guessed to be the name
      #   of this class in lower-case and "_id" suffixed. So a +Person+ class that makes a has_many association will use "person_id"
      #   as the default foreign_key.
      # * <tt>:dependent</tt>   - if set to true all the associated object are destroyed alongside this object.
      #   May not be set if :exclusively_dependent is also set.
      # * <tt>:exclusively_dependent</tt>   - if set to true all the associated object are deleted in one SQL statement without having their
      #   before_destroy callback run. This should only be used on associations that depend solely on this class and don't need to do any
      #   clean-up in before_destroy. The upside is that it's much faster, especially if there's a counter_cache involved.
      #   May not be set if :dependent is also set.
      # * <tt>:finder_sql</tt>  - specify a complete SQL statement to fetch the association. This is a good way to go for complex
      #   associations that depends on multiple tables. Note: When this option is used, +find_in_collection+ is _not_ added.
      # * <tt>:counter_sql</tt>  - specify a complete SQL statement to fetch the size of the association. If +:finder_sql+ is
      #   specified but +:counter_sql+, +:counter_sql+ will be generated by replacing SELECT ... FROM with SELECT COUNT(*) FROM.
      #
      # Option examples:
      #   has_many :comments, :order => "posted_on"
      #   has_many :people, :class_name => "Person", :conditions => "deleted = 0", :order => "name"
      #   has_many :tracks, :order => "position", :dependent => true
      #   has_many :subscribers, :class_name => "Person", :finder_sql =>
      #       'SELECT DISTINCT people.* ' +
      #       'FROM people p, post_subscriptions ps ' +
      #       'WHERE ps.post_id = #{id} AND ps.person_id = p.id ' +
      #       'ORDER BY p.first_name'
      def has_many(association_id, options = {})
        validate_options([ :foreign_key, :class_name, :exclusively_dependent, :dependent, :conditions, :order, :finder_sql, :counter_sql ], options.keys)
        association_name, association_class_name, association_class_primary_key_name =
              associate_identification(association_id, options[:class_name], options[:foreign_key])
 
        require_association_class(association_class_name)

        if options[:dependent] and options[:exclusively_dependent]
          raise ArgumentError, ':dependent and :exclusively_dependent are mutually exclusive options.  You may specify one or the other.' # ' ruby-mode
        elsif options[:dependent]
          module_eval "before_destroy '#{association_name}.each { |o| o.destroy }'"
        elsif options[:exclusively_dependent]
          module_eval "before_destroy { |record| #{association_class_name}.delete_all(%(#{association_class_primary_key_name} = \#{record.quoted_id})) }"
        end

        define_method(association_name) do |*params|
          force_reload = params.first unless params.empty?
          association = instance_variable_get("@#{association_name}")
          if association.nil?
            association = HasManyAssociation.new(self,
              association_name, association_class_name,
              association_class_primary_key_name, options)
            instance_variable_set("@#{association_name}", association)
          end
          association.reload if force_reload
          association
        end
        
        # deprecated api
        deprecated_collection_count_method(association_name)
        deprecated_add_association_relation(association_name)
        deprecated_remove_association_relation(association_name)
        deprecated_has_collection_method(association_name)
        deprecated_find_in_collection_method(association_name)
        deprecated_find_all_in_collection_method(association_name)
        deprecated_create_method(association_name)
        deprecated_build_method(association_name)
      end

      # Adds the following methods for retrival and query of a single associated object.
      # +association+ is replaced with the symbol passed as the first argument, so 
      # <tt>has_one :manager</tt> would add among others <tt>has_manager?</tt>.
      # * <tt>association(force_reload = false)</tt> - returns the associated object. Nil is returned if none is found.
      # * <tt>association=(associate)</tt> - assigns the associate object, extracts the primary key, sets it as the foreign key, 
      #   and saves the associate object.
      # * <tt>association?(object, force_reload = false)</tt> - returns true if the +object+ is of the same type and has the
      #   same id as the associated object.
      # * <tt>association.nil?</tt> - returns true if there is no associated object.
      # * <tt>build_association(attributes = {})</tt> - returns a new object of the associated type that has been instantiated
      #   with +attributes+ and linked to this object through a foreign key but has not yet been saved.
      # * <tt>create_association(attributes = {})</tt> - returns a new object of the associated type that has been instantiated
      #   with +attributes+ and linked to this object through a foreign key and that has already been saved (if it passed the validation).
      #
      # Example: An Account class declares <tt>has_one :beneficiary</tt>, which will add:
      # * <tt>Account#beneficiary</tt> (similar to <tt>Beneficiary.find_first "account_id = #{id}"</tt>)
      # * <tt>Account#beneficiary=(beneficiary)</tt> (similar to <tt>beneficiary.account_id = account.id; beneficiary.save</tt>)
      # * <tt>Account#beneficiary?</tt> (similar to <tt>account.beneficiary == some_beneficiary</tt>)
      # * <tt>Account#beneficiary.nil?</tt>
      # * <tt>Account#build_beneficiary</tt> (similar to <tt>Beneficiary.new("account_id" => id)</tt>)
      # * <tt>Account#create_beneficiary</tt> (similar to <tt>b = Beneficiary.new("account_id" => id); b.save; b</tt>)
      # The declaration can also include an options hash to specialize the behavior of the association.
      # 
      # Options are:
      # * <tt>:class_name</tt>  - specify the class name of the association. Use it only if that name can't be infered
      #   from the association name. So <tt>has_one :manager</tt> will by default be linked to the +Manager+ class, but
      #   if the real class name is +Person+, you'll have to specify it with this option.
      # * <tt>:conditions</tt>  - specify the conditions that the associated object must meet in order to be included as a "WHERE"
      #   sql fragment, such as "rank = 5".
      # * <tt>:order</tt>       - specify the order from which the associated object will be picked at the top. Specified as
      #    an "ORDER BY" sql fragment, such as "last_name, first_name DESC"
      # * <tt>:dependent</tt>   - if set to true the associated object is destroyed alongside this object
      # * <tt>:foreign_key</tt> - specify the foreign key used for the association. By default this is guessed to be the name
      #   of this class in lower-case and "_id" suffixed. So a +Person+ class that makes a has_one association will use "person_id"
      #   as the default foreign_key.
      #
      # Option examples:
      #   has_one :credit_card, :dependent => true
      #   has_one :last_comment, :class_name => "Comment", :order => "posted_on"
      #   has_one :project_manager, :class_name => "Person", :conditions => "role = 'project_manager'"
      def has_one(association_id, options = {})
        options.merge!({ :remote => true })
        belongs_to(association_id, options)

        association_name, association_class_name, class_primary_key_name =
            associate_identification(association_id, options[:class_name], options[:foreign_key], false)

        require_association_class(association_class_name)

        has_one_writer_method(association_name, association_class_name, class_primary_key_name)
        build_method("build_", association_name, association_class_name, class_primary_key_name)
        create_method("create_", association_name, association_class_name, class_primary_key_name)
        
        module_eval "before_destroy '#{association_name}.destroy if has_#{association_name}?'" if options[:dependent]
      end

      # Adds the following methods for retrival and query for a single associated object that this object holds an id to.
      # +association+ is replaced with the symbol passed as the first argument, so 
      # <tt>belongs_to :author</tt> would add among others <tt>has_author?</tt>.
      # * <tt>association(force_reload = false)</tt> - returns the associated object. Nil is returned if none is found.
      # * <tt>association=(associate)</tt> - assigns the associate object, extracts the primary key, and sets it as the foreign key.
      # * <tt>association?(object, force_reload = false)</tt> - returns true if the +object+ is of the same type and has the
      #   same id as the associated object.
      # * <tt>association.nil?</tt> - returns true if there is no associated object.
      #
      # Example: An Post class declares <tt>has_one :author</tt>, which will add:
      # * <tt>Post#author</tt> (similar to <tt>Author.find(author_id)</tt>)
      # * <tt>Post#author=(author)</tt> (similar to <tt>post.author_id = author.id</tt>)
      # * <tt>Post#author?</tt> (similar to <tt>post.author == some_author</tt>)
      # * <tt>Post#author.nil?</tt>
      # The declaration can also include an options hash to specialize the behavior of the association.
      # 
      # Options are:
      # * <tt>:class_name</tt>  - specify the class name of the association. Use it only if that name can't be infered
      #   from the association name. So <tt>has_one :author</tt> will by default be linked to the +Author+ class, but
      #   if the real class name is +Person+, you'll have to specify it with this option.
      # * <tt>:conditions</tt>  - specify the conditions that the associated object must meet in order to be included as a "WHERE"
      #   sql fragment, such as "authorized = 1".
      # * <tt>:order</tt>       - specify the order from which the associated object will be picked at the top. Specified as
      #   an "ORDER BY" sql fragment, such as "last_name, first_name DESC"
      # * <tt>:foreign_key</tt> - specify the foreign key used for the association. By default this is guessed to be the name
      #   of the associated class in lower-case and "_id" suffixed. So a +Person+ class that makes a belongs_to association to a
      #   +Boss+ class will use "boss_id" as the default foreign_key.
      # * <tt>:counter_cache</tt> - caches the number of belonging objects on the associate class through use of increment_counter 
      #   and decrement_counter. The counter cache is incremented when an object of this class is created and decremented when it's
      #   destroyed. This requires that a column named "#{table_name}_count" (such as comments_count for a belonging Comment class)
      #   is used on the associate class (such as a Post class).
      #
      # Option examples:
      #   belongs_to :firm, :foreign_key => "client_of"
      #   belongs_to :author, :class_name => "Person", :foreign_key => "author_id"
      #   belongs_to :valid_coupon, :class_name => "Coupon", :foreign_key => "coupon_id", 
      #              :conditions => 'discounts > #{payments_count}'
       def belongs_to(association_id, options = {})
          validate_options([ :class_name, :foreign_key, :remote, :conditions, :order, :dependent, :counter_cache ], options.keys)

          association_name, association_class_name, class_primary_key_name =
              associate_identification(association_id, options[:class_name], options[:foreign_key], false)

          require_association_class(association_class_name)

          association_class_primary_key_name = options[:foreign_key] || Inflector.underscore(Inflector.demodulize(association_class_name)) + "_id"

          if options[:remote]
            association_finder = <<-"end_eval"
              #{association_class_name}.find_first(
                "#{class_primary_key_name} = \#{quoted_id}#{options[:conditions] ? " AND " + options[:conditions] : ""}",
                #{options[:order] ? "\"" + options[:order] + "\"" : "nil" }
              )
            end_eval
          else
            association_finder = options[:conditions] ?
              "#{association_class_name}.find_on_conditions(#{association_class_primary_key_name}, \"#{options[:conditions]}\")" :
              "#{association_class_name}.find(#{association_class_primary_key_name})"
          end

          has_association_method(association_name)
          association_reader_method(association_name, association_finder)
          belongs_to_writer_method(association_name, association_class_name, association_class_primary_key_name)
          association_comparison_method(association_name, association_class_name)

          if options[:counter_cache]
            module_eval(
              "after_create '#{association_class_name}.increment_counter(\"#{Inflector.pluralize(self.to_s.downcase). + "_count"}\", #{association_class_primary_key_name})" +
              " if has_#{association_name}?'"
            )

            module_eval(
              "before_destroy '#{association_class_name}.decrement_counter(\"#{Inflector.pluralize(self.to_s.downcase) + "_count"}\", #{association_class_primary_key_name})" +
              " if has_#{association_name}?'"
            )          
          end
        end

      # Associates two classes via an intermediate join table.  Unless the join table is explicitly specified as
      # an option, it is guessed using the lexical order of the class names. So a join between Developer and Project
      # will give the default join table name of "developers_projects" because "D" outranks "P".
      #
      # Any additional fields added to the join table will be placed as attributes when pulling records out through
      # has_and_belongs_to_many associations. This is helpful when have information about the association itself
      # that you want available on retrival.
      #
      # Adds the following methods for retrival and query.
      # +collection+ is replaced with the symbol passed as the first argument, so 
      # <tt>has_and_belongs_to_many :categories</tt> would add among others +add_categories+.
      # * <tt>collection(force_reload = false)</tt> - returns an array of all the associated objects.
      #   An empty array is returned if none is found.
      # * <tt>collection<<(object, ...)</tt> - adds one or more objects to the collection by creating associations in the join table 
      #   (collection.push and collection.concat are aliases to this method).
      # * <tt>collection.push_with_attributes(object, join_attributes)</tt> - adds one to the collection by creating an association in the join table that
      #   also holds the attributes from <tt>join_attributes</tt> (should be a hash with the column names as keys). This can be used to have additional
      #   attributes on the join, which will be injected into the associated objects when they are retrieved through the collection.
      #   (collection.concat_with_attributes is an alias to this method).
      # * <tt>collection.delete(object, ...)</tt> - removes one or more objects from the collection by removing their associations from the join table.  
      #   This does not destroy the objects.
      # * <tt>collection.clear</tt> - removes every object from the collection. This does not destroy the objects.
      # * <tt>collection.empty?</tt> - returns true if there are no associated objects.
      # * <tt>collection.size</tt> - returns the number of associated objects.
      #
      # Example: An Developer class declares <tt>has_and_belongs_to_many :projects</tt>, which will add:
      # * <tt>Developer#projects</tt>
      # * <tt>Developer#projects<<</tt>
      # * <tt>Developer#projects.delete</tt>
      # * <tt>Developer#projects.clear</tt>
      # * <tt>Developer#projects.empty?</tt>
      # * <tt>Developer#projects.size</tt>
      # * <tt>Developer#projects.find(id)</tt>
      # The declaration may include an options hash to specialize the behavior of the association.
      # 
      # Options are:
      # * <tt>:class_name</tt> - specify the class name of the association. Use it only if that name can't be infered
      #   from the association name. So <tt>has_and_belongs_to_many :projects</tt> will by default be linked to the 
      #   +Project+ class, but if the real class name is +SuperProject+, you'll have to specify it with this option.
      # * <tt>:join_table</tt> - specify the name of the join table if the default based on lexical order isn't what you want.
      #   WARNING: If you're overwriting the table name of either class, the table_name method MUST be declared underneath any
      #   has_and_belongs_to_many declaration in order to work.
      # * <tt>:foreign_key</tt> - specify the foreign key used for the association. By default this is guessed to be the name
      #   of this class in lower-case and "_id" suffixed. So a +Person+ class that makes a has_and_belongs_to_many association
      #   will use "person_id" as the default foreign_key.
      # * <tt>:association_foreign_key</tt> - specify the association foreign key used for the association. By default this is
      #   guessed to be the name of the associated class in lower-case and "_id" suffixed. So the associated class is +Project+
      #   that makes a has_and_belongs_to_many association will use "project_id" as the default association foreign_key.
      # * <tt>:conditions</tt>  - specify the conditions that the associated object must meet in order to be included as a "WHERE"
      #   sql fragment, such as "authorized = 1".
      # * <tt>:order</tt> - specify the order in which the associated objects are returned as a "ORDER BY" sql fragment, such as "last_name, first_name DESC"
      # * <tt>:uniq</tt> - if set to true, duplicate associated objects will be ignored by accessors and query methods
      # * <tt>:finder_sql</tt> - overwrite the default generated SQL used to fetch the association with a manual one
      # * <tt>:delete_sql</tt> - overwrite the default generated SQL used to remove links between the associated 
      #   classes with a manual one
      # * <tt>:insert_sql</tt> - overwrite the default generated SQL used to add links between the associated classes
      #   with a manual one
      #
      # Option examples:
      #   has_and_belongs_to_many :projects
      #   has_and_belongs_to_many :nations, :class_name => "Country"
      #   has_and_belongs_to_many :categories, :join_table => "prods_cats"
      def has_and_belongs_to_many(association_id, options = {})
        validate_options([ :class_name, :table_name, :foreign_key, :association_foreign_key, :conditions,
                           :join_table, :finder_sql, :delete_sql, :insert_sql, :order, :uniq ], options.keys)
        association_name, association_class_name, association_class_primary_key_name =
              associate_identification(association_id, options[:class_name], options[:foreign_key])

        require_association_class(association_class_name)

        join_table = options[:join_table] || 
          join_table_name(undecorated_table_name(self.to_s), undecorated_table_name(association_class_name))
        
        define_method(association_name) do |*params|
          force_reload = params.first unless params.empty?
          association = instance_variable_get("@#{association_name}")
          if association.nil?
            association = HasAndBelongsToManyAssociation.new(self,
              association_name, association_class_name,
              association_class_primary_key_name, join_table, options)
            instance_variable_set("@#{association_name}", association)
          end
          association.reload if force_reload
          association
        end

        before_destroy_sql = "DELETE FROM #{join_table} WHERE #{association_class_primary_key_name} = \\\#{self.quoted_id}"
        module_eval(%{before_destroy "self.connection.delete(%{#{before_destroy_sql}})"}) # "
        
        # deprecated api
        deprecated_collection_count_method(association_name)
        deprecated_add_association_relation(association_name)
        deprecated_remove_association_relation(association_name)
        deprecated_has_collection_method(association_name)
      end

      # Loads the <tt>file_name</tt> if reload_associations is true or requires if it's false.
      def require_association(file_name)
        if !associations_loaded.include?(file_name)
          associations_loaded << file_name
          reload_associations ? silence_warnings { load("#{file_name}.rb") } : require(file_name)
        end
      end

      # Resets the list of dependencies loaded (typically to be called by the end of a request), so when require_association is
      # called for that dependency it'll be loaded anew.
      def reset_associations_loaded
        self.associations_loaded = []
      end
      
      # Reload all the associations that have already been loaded once.
      def reload_associations_loaded
        associations_loaded.each do |file_name| 
          begin
            silence_warnings { load("#{file_name}.rb") }
          rescue LoadError
            # The association didn't reside in its own file, so we assume it was required by other means
          end
        end
      end

      private
        # Raises an exception if an invalid option has been specified to prevent misspellings from slipping through 
        def validate_options(valid_option_keys, supplied_option_keys)
          unknown_option_keys = supplied_option_keys - valid_option_keys
          raise(ActiveRecord::ActiveRecordError, "Unknown options: #{unknown_option_keys}") unless unknown_option_keys.empty?
        end
        
        def join_table_name(first_table_name, second_table_name)
          if first_table_name < second_table_name
            join_table = "#{first_table_name}_#{second_table_name}"
          else
            join_table = "#{second_table_name}_#{first_table_name}"
          end

          table_name_prefix + join_table + table_name_suffix
        end
        
        def associate_identification(association_id, association_class_name, foreign_key, plural = true)
          if association_class_name !~ /::/
            association_class_name = type_name_with_module(
              association_class_name || 
                Inflector.camelize(plural ? Inflector.singularize(association_id.id2name) : association_id.id2name)
            )
          end

          primary_key_name = foreign_key || Inflector.underscore(Inflector.demodulize(name)) + "_id"
        
          return association_id.id2name, association_class_name, primary_key_name
        end
        
        def association_comparison_method(association_name, association_class_name)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def #{association_name}?(comparison_object, force_reload = false)
              if comparison_object.kind_of?(#{association_class_name})
                #{association_name}(force_reload) == comparison_object
              else
                raise "Comparison object is a #{association_class_name}, should have been \#{comparison_object.class.name}"
              end
            end
          end_eval
        end

        def association_reader_method(association_name, association_finder)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def #{association_name}(force_reload = false)
              if @#{association_name}.nil? || force_reload
                begin
                  @#{association_name} = #{association_finder}
                rescue ActiveRecord::StatementInvalid, ActiveRecord::RecordNotFound
                  nil
                end
              end
              
              return @#{association_name}
            end
          end_eval
        end

        def has_one_writer_method(association_name, association_class_name, class_primary_key_name)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def #{association_name}=(association)
              if association.nil?
                @#{association_name}.#{class_primary_key_name} = nil
                @#{association_name}.save(false)
                @#{association_name} = nil
              else
                raise ActiveRecord::AssociationTypeMismatch unless #{association_class_name} === association
                association.#{class_primary_key_name} = id
                association.save(false)
                @#{association_name} = association
              end
            end
          end_eval
        end

        def belongs_to_writer_method(association_name, association_class_name, association_class_primary_key_name)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def #{association_name}=(association)
              if association.nil?
                @#{association_name} = self.#{association_class_primary_key_name} = nil
              else
                raise ActiveRecord::AssociationTypeMismatch unless #{association_class_name} === association
                @#{association_name} = association
                self.#{association_class_primary_key_name} = association.id
              end
            end
          end_eval
        end

        def has_association_method(association_name)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def has_#{association_name}?(force_reload = false)
              !#{association_name}(force_reload).nil?
            end
          end_eval
        end
        
        def build_method(method_prefix, collection_name, collection_class_name, class_primary_key_name)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def #{method_prefix + collection_name}(attributes = {})
              association = #{collection_class_name}.new
              association.attributes = attributes.merge({ "#{class_primary_key_name}" => id})
              association
            end
          end_eval
        end

        def create_method(method_prefix, collection_name, collection_class_name, class_primary_key_name)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def #{method_prefix + collection_name}(attributes = nil)
              #{collection_class_name}.create((attributes || {}).merge({ "#{class_primary_key_name}" => id}))
            end
          end_eval
        end

        def require_association_class(class_name)
          return unless class_name
          
          begin
            require_association(Inflector.underscore(class_name))
          rescue LoadError
            # Failed to load the associated class -- let's hope the developer is doing the requiring himself.
          end
        end
    end
  end
end