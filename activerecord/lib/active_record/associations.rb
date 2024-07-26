module ActiveRecord
  module Associations # :nodoc:
    def self.append_features(base)
      super
      base.extend(ClassMethods)
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
    # The project class now has the following methods to ease the traversel and manipulation of its relationships:
    # * <tt>Project#portfolio, Project#portfolio=(portfolio), Project#has_portfolio?, Project#portfolio?(portfolio),</tt>
    #   <tt>Project#build_portfolio, Project#create_portfolio</tt>
    # * <tt>Project#project_manager, Project#project_manager=(project_manager), Project#has_project_manger?,</tt>
    #   <tt>Project#project_manager?(project_manager), Project#build_project_manager, Project#create_project_manager</tt>
    # * <tt>Project#has_milestones?, Project#milestones_count, Project#milestones, Project#milestones<<(milestone),
    #   Project#find_in_milestones(milestone_id), Project#build_to_milestones, Project#create_in_milestones<</tt>
    # * <tt>Project#has_categories?, Project#categories_count, Project#categories, Project#add_categories(category1, category2), </tt>
    #   <tt>Project#remove_categories(category1)</tt>
    #
    # == Caching
    #
    # All of the methods are built on a simple caching principle that will keep the result of the last query around unless specifically
    # instructed not to. The cache is even shared across methods to make it even cheaper to use the macro-added methods without 
    # worrying too much about performance at the first go. Example:
    #
    #   project.milestones             # fetches milestones from the database
    #   project.milestones_count       # uses the milestone cache
    #   project.has_milestones?        # uses the milestone cache
    #   project.milestones_count(true) # fetches milestones from the database
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
    # == Options
    #
    # All of the association macros can be specialized through options which makes more complex cases than the simple and guessable ones
    # possible.
    module ClassMethods
      # Adds the following methods for retrival and query of collections of associated objects.
      # +collection+ is replaced with the symbol passed as the first argument, so 
      # <tt>has_many :clients</tt> would add among others <tt>has_clients?</tt>.
      # * <tt>collection(force_reload = false)</tt> - returns an array of all the associated objects.
      #   An empty array is returned if none is found.
      # * <tt>collection<<(object)</tt> - adds the object to the collection (by setting the foreign key on it) and saves it.
      # * <tt>has_collection?(force_reload = false)</tt> - returns true if there's any associated objects.
      # * <tt>collection_count(force_reload = false)</tt> - returns the number of associated objects.
      # * <tt>find_in_collection(id)</tt> - finds an associated object responding to the +id+ and that
      #   meets the condition that it has to be associated with this object.
      # * <tt>build_to_collection(attributes = {})</tt> - returns a new object of the collection type that has been instantiated
      #   with +attributes+ and linked to this object through a foreign key but has not yet been saved.
      # * <tt>create_in_collection(attributes = {})</tt> - returns a new object of the collection type that has been instantiated
      #   with +attributes+ and linked to this object through a foreign key and that has already been saved (if it passed the validation).
      #
      # Example: A Firm class declares <tt>has_many :clients</tt>, which will add:
      # * <tt>Firm#clients</tt> (similar to <tt>Clients.find_all "firm_id = #{id}"</tt>)
      # * <tt>Firm#has_clients?</tt> (similar to <tt>firm.clients.length > 0</tt>)
      # * <tt>Firm#clients_count</tt> (similar to <tt>Client.count "firm_id = #{id}"</tt>)
      # * <tt>Firm#find_in_clients</tt> (similar to <tt>Client.find_on_conditions(id, "firm_id = #{id}"</tt>)
      # * <tt>Firm#build_to_clients</tt> (similar to <tt>Client.new("firm_id" => id)</tt>)
      # * <tt>Firm#create_in_clients</tt> (similar to <tt>c = Client.new("client_id" => id); c.save; c</tt>)
      # The declaration can also include an options hash to specialize the generated methods.
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
      # * <tt>:dependent</tt>   - if set to true all the associated object are destroyed alongside this object
      # * <tt>:finder_sql</tt>  - specify a complete SQL statement to fetch the association. This is a good way to go for complex
      #   associations that depends on multiple tables. Note: When this option is used, +find_in_collection+ is _not_ added.
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
      def has_many(collection_id, options = {})
        validate_options([ :foreign_key, :class_name, :dependent, :conditions, :order, :finder_sql ], options.keys)

        collection_name, collection_class_name, class_primary_key_name =
            associate_identification(collection_id, options[:class_name], options[:foreign_key])

        if options[:finder_sql]
          counter_sql = options[:finder_sql].gsub(/SELECT (.*) FROM/, "SELECT COUNT(*) FROM")

          collection_finder  = "#{collection_class_name}.find_by_sql(\"#{options[:finder_sql]}\")"
          collection_counter = "#{collection_class_name}.count_by_sql(\"#{counter_sql}\")"
        else
          collection_finder = <<-"end_eval"
            #{collection_class_name}.find_all(
              "#{class_primary_key_name} = '\#{id}'#{options[:conditions] ? " AND " + options[:conditions] : ""}",
              #{options[:order] ? "\"" + options[:order] + "\"" : "nil" }
            )
          end_eval
          
          collection_counter = "#{collection_class_name}.count(\"#{class_primary_key_name} = '\#{id}'\")"
        end
	
        has_collection_method(collection_name)
        collection_count_method(collection_name, collection_counter)
        collection_accessor_method(collection_name, collection_finder, class_primary_key_name)
				
        build_method("build_to_", collection_name, collection_class_name, class_primary_key_name)
        create_method("create_in_", collection_name, collection_class_name, class_primary_key_name)

        # Can't use constrained finds with specialized finder SQL
        unless options[:finder_sql]
          find_in_collection_method(collection_name, collection_class_name, class_primary_key_name, options[:conditions])
        end

        module_eval "before_destroy '#{collection_name}.each { |o| o.destroy }'" if options[:dependent]
      end

      # Adds the following methods for retrival and query of a single associated object.
      # +association+ is replaced with the symbol passed as the first argument, so 
      # <tt>has_one :manager</tt> would add among others <tt>has_manager?</tt>.
      # * <tt>association(force_reload = false)</tt> - returns the associated object. Nil is returned if none is found.
      # * <tt>association=(associate)</tt> - assigns the associate object, extracts the primary key, sets it as the foreign key, 
      #   and saves the associate object.
      # * <tt>association?(object, force_reload = false)</tt> - returns true if the +object+ is of the same type and has the
      #   same id as the associated object.
      # * <tt>has_association?(force_reload = false)</tt> - returns true if there's an associated object.
      # * <tt>build_association(attributes = {})</tt> - returns a new object of the associated type that has been instantiated
      #   with +attributes+ and linked to this object through a foreign key but has not yet been saved.
      # * <tt>create_association(attributes = {})</tt> - returns a new object of the associated type that has been instantiated
      #   with +attributes+ and linked to this object through a foreign key and that has already been saved (if it passed the validation).
      #
      # Example: An Account class declares <tt>has_one :beneficiary</tt>, which will add:
      # * <tt>Account#beneficiary</tt> (similar to <tt>Beneficiary.find_first "account_id = #{id}"</tt>)
      # * <tt>Account#beneficiary=(beneficiary)</tt> (similar to <tt>beneficiary.account_id = account.id; beneficiary.save</tt>)
      # * <tt>Account#beneficiary?</tt> (similar to <tt>account.beneficiary == some_beneficiary</tt>)
      # * <tt>Account#has_beneficiary?</tt> (similar to <tt>!account.beneficiary.nil?</tt>)
      # * <tt>Account#build_beneficiary</tt> (similar to <tt>Beneficiary.new("account_id" => id)</tt>)
      # * <tt>Account#create_beneficiary</tt> (similar to <tt>b = Beneficiary.new("account_id" => id); b.save; b</tt>)
      # The declaration can also include an options hash to specialize the generated methods.
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
            associate_identification(association_id, options[:class_name], options[:foreign_key])

        has_one_writer_method(association_name, class_primary_key_name)
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
      # * <tt>has_association?(force_reload = false)</tt> - returns true if there's an associated object.
      #
      # Example: An Post class declares <tt>has_one :author</tt>, which will add:
      # * <tt>Post#author</tt> (similar to <tt>Author.find(author_id)</tt>)
      # * <tt>Post#author=(author)</tt> (similar to <tt>post.author_id = author.id</tt>)
      # * <tt>Post#author?</tt> (similar to <tt>post.author == some_author</tt>)
      # * <tt>Post#has_author?</tt> (similar to <tt>!post.author.nil?</tt>)
      # The declaration can also include an options hash to specialize the generated methods.
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
            associate_identification(association_id, options[:class_name], options[:foreign_key])

        association_class_primary_key_name = options[:foreign_key] || association_class_name.gsub(/^.*::/, '').downcase + "_id"

        if options[:remote]
          association_finder = <<-"end_eval"
            #{association_class_name}.find_first(
              "#{class_primary_key_name} = '\#{id}'#{options[:conditions] ? " AND " + options[:conditions] : ""}",
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
        belongs_to_writer_method(association_name, association_class_primary_key_name)
        association_comparison_method(association_name, association_class_name)

        if options[:counter_cache]
          module_eval(
            "after_create '#{association_class_name}.increment_counter(\"#{table_name + "_count"}\", #{association_class_primary_key_name})" +
            " if has_#{association_name}?'"
          )

          module_eval(
            "before_destroy '#{association_class_name}.decrement_counter(\"#{table_name + "_count"}\", #{association_class_primary_key_name})" +
            " if has_#{association_name}?'"
          )          
        end
      end

      # Associates two classes via an intermediate join table.  Unless the join table is explicitly specified as
      # an option, it is guessed using the lexical order of the class names. So a join between Developer and Project
      # will give the default join table name of "developers_projects" because "D" outranks "C".
      # Adds the following methods for retrival and query.
      # +collection+ is replaced with the symbol passed as the first argument, so 
      # <tt>has_and_belongs_to_many :categories</tt> would add among others +add_categories+.
      # * <tt>collection(force_reload = false)</tt> - returns an array of all the associated objects.
      #   An empty array is returned if none is found.
      # * <tt>has_collection?(force_reload = false)</tt> - returns true if there's any associated objects.
      # * <tt>collection_count(force_reload = false)</tt> - returns the number of associated objects.
      # * <tt>add_collection(object1, object2)</tt> - adds an association between this object and the objects given as arguments.
      #   The object arguments can either be given one by one or in an array.
      # * <tt>remove_collection(object1, object2)</tt> - removes the association between this object and the objects given as 
      #   arguments. The object arguments can either be given one by one or in an array.
      #
      # Example: An Developer class declares <tt>has_and_belongs_to_many :projects</tt>, which will add:
      # * <tt>Developer#projects</tt>
      # * <tt>Developer#has_projects?</tt>
      # * <tt>Developer#projects_count</tt>
      # * <tt>Developer#add_projects</tt>
      # * <tt>Developer#remove_projects</tt>
      # The declaration can also include an options hash to specialize the generated methods.
      # 
      # Options are:
      # * <tt>:class_name</tt> - specify the class name of the association. Use it only if that name can't be infered
      #   from the association name. So <tt>has_and_belongs_to_many :projects</tt> will by default be linked to the 
      #   +Project+ class, but if the real class name is +SuperProject+, you'll have to specify it with this option.
      # * <tt>:join_table</tt> - specify the name of the join table if the default based on lexical order isn't what you want
      # * <tt>:foreign_key</tt> - specify the foreign key used for the association. By default this is guessed to be the name
      #   of this class in lower-case and "_id" suffixed. So a +Person+ class that makes a has_and_belongs_to_many association
      #   will use "person_id" as the default foreign_key.
      # * <tt>:association_foreign_key</tt> - specify the association foreign key used for the association. By default this is
      #   guessed to be the name of the associated class in lower-case and "_id" suffixed. So the associated class is +Project+
      #   that makes a has_and_belongs_to_many association will use "project_id" as the default association foreign_key.
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
        validate_options([ :class_name, :table_name, :foreign_key, :association_foreign_key,
                           :join_table, :finder_sql, :delete_sql, :insert_sql ], options.keys)

        association_name, association_class_name, class_primary_key_name =
            associate_identification(association_id, options[:class_name], options[:foreign_key])


        association_foreign_key = options[:association_foreign_key] || association_class_name.downcase + "_id"

        association_table_name = options[:table_name] || table_name(association_class_name)
        my_key      = options[:key] || name.downcase + "_id"
        join_table  = options[:join_table] || 
          join_table_name(undecorated_table_name(self.to_s), undecorated_table_name(association_class_name))

        finder_sql  = 
          options[:finder_sql] ||
          "SELECT t.* FROM #{association_table_name} t, #{join_table} j " +
          "WHERE t.id = j.#{association_foreign_key} AND j.#{class_primary_key_name} = '\#{id}' ORDER BY t.id"

        has_collection_method(association_name)
        collection_reader_method(association_name, "#{association_class_name}.find_by_sql(\"#{finder_sql}\")")
        collection_count_method(association_name, "#{association_name}.length")

        add_association_relation(
          association_name, 
          options[:insert_sql] || 
            "INSERT INTO #{join_table} (#{class_primary_key_name}, #{association_foreign_key}) " +
            "VALUES ('\#{id}', '\#{item.id}')"
        )

        remove_association_relation(
          association_name, association_foreign_key, 
          options[:delete_sql] || "DELETE FROM #{join_table} WHERE #{class_primary_key_name} = '\#{id}'"
        )
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

        def associate_identification(association_id, association_class_name, foreign_key)
          if association_class_name !~ /::/
            association_class_name = type_name_with_module(
              association_class_name || 
              class_name(table_name_prefix + association_id.id2name + table_name_suffix)
            )
          end

          primary_key_name = foreign_key || name.gsub(/.*::/, "").downcase + "_id"
        
          return association_id.id2name, association_class_name, primary_key_name
        end
        
        def collection_reader_method(collection_name, collection_finder)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def #{collection_name}(force_reload = false)
              if @#{collection_name}.nil? || force_reload
                begin
                  @#{collection_name} = #{collection_finder}
                rescue ActiveRecord::StatementInvalid, ActiveRecord::RecordNotFound
                  @#{collection_name} = []
                end
              end
              
              return @#{collection_name}
            end
          end_eval
        end
				
        def collection_accessor_method(collection_name, collection_finder, class_primary_key_name)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def #{collection_name}(force_reload = false)
              if @#{collection_name}.nil? || force_reload
                begin
                  @#{collection_name} = #{collection_finder}
                rescue ActiveRecord::StatementInvalid, ActiveRecord::RecordNotFound
                  @#{collection_name} = []
                end
              end
              
              def @#{collection_name}.owner; @owner; end
              def @#{collection_name}.owner=(owner); @owner = owner; end
              @#{collection_name}.owner = self
              def @#{collection_name}.<<(association)
                association.#{class_primary_key_name} = owner.id
                association.save(false)
                super association
              end

              return @#{collection_name}
            end
          end_eval
        end

        def has_collection_method(collection_name)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def has_#{collection_name}?(force_reload = false)
              #{collection_name}(force_reload).length > 0
            end
          end_eval
        end

        def collection_count_method(collection_name, collection_counter)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def #{collection_name}_count(force_reload = false)
              return read_attribute("#{collection_name}_count") if read_attribute("#{collection_name}_count")
              if @#{collection_name}.nil? || force_reload
                #{collection_counter}
              else
                @#{collection_name}.length
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

        def has_one_writer_method(association_name, class_primary_key_name)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def #{association_name}=(association)
              @#{association_name} = association
              association.#{class_primary_key_name} = id
              association.save(false)
            end
          end_eval
        end

        def belongs_to_writer_method(association_name, association_class_primary_key_name)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def #{association_name}=(association)
              @#{association_name} = association
              self.#{association_class_primary_key_name} = association.id
            end
          end_eval
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
        
        def find_in_collection_method(collection_name, collection_class_name, class_primary_key_name, conditions = nil)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def find_in_#{collection_name}(association_id)
              #{collection_class_name}.find_on_conditions(
                association_id, "#{class_primary_key_name} = '\#{id}'#{conditions ? " AND " + conditions : ""}"
              )
            end
          end_eval
        end
        
        def add_association_relation(association_name, insert_sql)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def add_#{association_name}(*items)
              items.flatten.each { |item| connection.insert "#{insert_sql}" }
              @#{association_name} = nil
            end
          end_eval
        end
        
        def remove_association_relation(association_name, foreign_key, delete_sql)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def remove_#{association_name}(*items)
              if items.flatten.length < 1
                connection.delete "#{delete_sql}"
              else
                ids = items.flatten.map { |item| "'" + item.id.to_s + "'" }.join(',')
                connection.delete "#{delete_sql} AND #{foreign_key} in (\#{ids})"
              end
              @#{association_name} = nil
            end
          end_eval
        end
    end
  end
end