require 'active_record/support/class_attribute_accessors'
require 'active_record/support/class_inheritable_attributes'
require 'active_record/support/inflector'
require 'yaml'

module ActiveRecord #:nodoc:
  class ActiveRecordError < StandardError #:nodoc:
  end
  class SubclassNotFound < ActiveRecordError #:nodoc:
  end
  class AssociationTypeMismatch < ActiveRecordError #:nodoc:
  end
  class SerializationTypeMismatch < ActiveRecordError #:nodoc:
  end
  class AdapterNotSpecified < ActiveRecordError # :nodoc:
  end
  class AdapterNotFound < ActiveRecordError # :nodoc:
  end
  class ConnectionNotEstablished < ActiveRecordError #:nodoc:
  end
  class ConnectionFailed < ActiveRecordError #:nodoc:
  end
  class RecordNotFound < ActiveRecordError #:nodoc:
  end
  class StatementInvalid < ActiveRecordError #:nodoc:
  end
  class PreparedStatementInvalid < ActiveRecordError #:nodoc:
  end
  class StaleObjectError < ActiveRecordError #:nodoc:
  end

  # Active Record objects doesn't specify their attributes directly, but rather infer them from the table definition with
  # which they're linked. Adding, removing, and changing attributes and their type is done directly in the database. Any change
  # is instantly reflected in the Active Record objects. The mapping that binds a given Active Record class to a certain
  # database table will happen automatically in most common cases, but can be overwritten for the uncommon ones. 
  # 
  # See the mapping rules in table_name and the full example in link:files/README.html for more insight.
  # 
  # == Creation
  # 
  # Active Records accepts constructor parameters either in a hash or as a block. The hash method is especially useful when
  # you're receiving the data from somewhere else, like a HTTP request. It works like this:
  # 
  #   user = User.new("name" => "David", "occupation" => "Code Artist")
  #   user.name # => "David"
  # 
  # You can also use block initialization:
  # 
  #   user = User.new do |u|
  #     u.name = "David"
  #     u.occupation = "Code Artist"
  #   end
  # 
  # And of course you can just create a bare object and specify the attributes after the fact:
  # 
  #   user = User.new
  #   user.name = "David"
  #   user.occupation = "Code Artist"
  # 
  # == Conditions
  # 
  # Conditions can either be specified as a string or an array representing the WHERE-part of an SQL statement.
  # The array form is to be used when the condition input is tainted and requires sanitization. The string form can
  # be used for statements that doesn't involve tainted data. Examples:
  # 
  #   User < ActiveRecord::Base
  #     def self.authenticate_unsafely(user_name, password)
  #       find_first("user_name = '#{user_name}' AND password = '#{password}'")
  #     end
  # 
  #     def self.authenticate_safely(user_name, password)
  #       find_first([ "user_name = ? AND password = ?", user_name, password ])
  #     end
  #   end
  # 
  # The <tt>authenticate_unsafely</tt> method inserts the parameters directly into the query and is thus susceptible to SQL-injection
  # attacks if the <tt>user_name</tt> and +password+ parameters come directly from a HTTP request. The <tt>authenticate_safely</tt> method, 
  # on the other hand, will sanitize the <tt>user_name</tt> and +password+ before inserting them in the query, which will ensure that
  # an attacker can't escape the query and fake the login (or worse).
  #
  # == Overwriting default accessors
  # 
  # All column values are automatically available through basic accessors on the Active Record object, but some times you
  # want to specialize this behavior. This can be done by either by overwriting the default accessors (using the same
  # name as the attribute) calling read_attribute(attr_name) and write_attribute(attr_name, value) to actually change things.
  # Example:
  # 
  #   class Song < ActiveRecord::Base
  #     # Uses an integer of seconds to hold the length of the song
  #     
  #     def length=(minutes)
  #       write_attribute("length", minutes * 60)
  #     end
  #     
  #     def length
  #       read_attribute("length") / 60
  #     end
  #   end
  # 
  # == Dynamic attribute-based finders
  #
  # Dynamic attribute-based finders are a cleaner way of getting objects by simple queries without turning to SQL. They work by
  # appending the name of an attribute to <tt>find_by_</tt>, so you get finders like <tt>Person.find_by_user_name, Payment.find_by_transaction_id</tt>.
  # So instead of writing <tt>Person.find_first(["user_name = ?", user_name])</tt>, you just do <tt>Person.find_by_user_name(user_name)</tt>.
  # 
  # It's also possible to use multiple attributes in the same find by separating them with "_and_", so you get finders like
  # <tt>Person.find_by_user_name_and_password</tt> or even <tt>Payment.find_by_purchaser_and_state_and_country</tt>. So instead of writing
  # <tt>Person.find_first(["user_name = ? AND password = ?", user_name, password])</tt>, you just do 
  # <tt>Person.find_by_user_name_and_password(user_name, password)</tt>.
  #
  # While primarily a construct for easier find_firsts, it can also be used as a construct for find_all by using calls like 
  # <tt>Payment.find_all_by_amount(50)</tt> that is turned into <tt>Payment.find_all(["amount = ?", 50])</tt>. This is something not as equally useful,
  # though, as it's not possible to specify the order in which the objects are returned.
  #
  # == Saving arrays, hashes, and other non-mappeable objects in text columns
  # 
  # Active Record can serialize any object in text columns using YAML. To do so, you must specify this with a call to the class method +serialize+. 
  # This makes it possible to store arrays, hashes, and other non-mappeable objects without doing any additional work. Example:
  # 
  #   class User < ActiveRecord::Base
  #     serialize :preferences
  #   end
  # 
  #   user = User.create("preferences" => { "background" => "black", "display" => large })
  #   User.find(user.id).preferences # => { "background" => "black", "display" => large }
  # 
  # You can also specify an optional :class_name option that'll raise an exception if a serialized object is retrieved as a 
  # descendent of a class not in the hierarchy. Example:
  # 
  #   class User < ActiveRecord::Base
  #     serialize :preferences, :class_name => "Hash"
  #   end
  # 
  #   user = User.create("preferences" => %w( one two three ))
  #   User.find(user.id).preferences    # raises SerializationTypeMismatch
  # 
  # == Single table inheritance
  #
  # Active Record allows inheritance by storing the name of the class in a column that by default is called "type" (can be changed 
  # by overwriting <tt>Base.inheritance_column</tt>). This means that an inheritance looking like this:
  #
  #   class Company < ActiveRecord::Base; end
  #   class Firm < Company; end
  #   class Client < Company; end
  #   class PriorityClient < Client; end
  #
  # When you do Firm.create("name" => "37signals"), this record with be saved in the companies table with type = "Firm". You can then
  # fetch this row again using Company.find_first "name = '37signals'" and it will return a Firm object.
  #
  # If you don't have a type column defined in your table, single-table inheritance won't be triggered. In that case, it'll work just
  # like normal subclasses with no special magic for differentiating between them or reloading the right type with find.
  #
  # Note, all the attributes for all the cases are kept in the same table. Read more:
  # http://www.martinfowler.com/eaaCatalog/singleTableInheritance.html
  # 
  # == Connection to multiple databases in different models
  #
  # Connections are usually created through ActiveRecord::Base.establish_connection and retrieved by ActiveRecord::Base.connection.
  # All classes inheriting from ActiveRecord::Base will use this connection. But you can also set a class-specific connection. 
  # For example, if Course is a ActiveRecord::Base, but resides in a different database you can just say Course.establish_connection
  # and Course *and all its subclasses* will use this connection instead.
  #
  # This feature is implemented by keeping a connection pool in ActiveRecord::Base that is a Hash indexed by the class. If a connection is
  # requested, the retrieve_connection method will go up the class-hierarchy until a connection is found in the connection pool.
  #
  # == Exceptions
  # 
  # * +ActiveRecordError+ -- generic error class and superclass of all other errors raised by Active Record
  # * +AdapterNotSpecified+ -- the configuration hash used in <tt>establish_connection</tt> didn't include a 
  #   <tt>:adapter</tt> key.
  # * +AdapterNotSpecified+ -- the <tt>:adapter</tt> key used in <tt>establish_connection</tt> specified an unexisting adapter
  #   (or a bad spelling of an existing one). 
  # * +AssociationTypeMismatch+ -- the object assigned to the association wasn't of the type specified in the association definition. 
  # * +SerializationTypeMismatch+ -- the object serialized wasn't of the class specified in the <tt>:class_name</tt> option of 
  #   the serialize definition. 
  # * +ConnectionNotEstablished+ -- no connection has been established. Use <tt>establish_connection</tt> before querying.
  # * +RecordNotFound+ -- no record responded to the find* method. 
  #   Either the row with the given ID doesn't exist or the row didn't meet the additional restrictions.
  # * +StatementInvalid+ -- the database server rejected the SQL statement. The precise error is added in the  message.
  #   Either the record with the given ID doesn't exist or the record didn't meet the additional restrictions.
  # 
  # *Note*: The attributes listed are class-level attributes (accessible from both the class and instance level). 
  # So it's possible to assign a logger to the class through Base.logger= which will then be used by all
  # instances in the current object space.
  class Base
    include ClassInheritableAttributes
  
    # Accepts a logger conforming to the interface of Log4r or the default Ruby 1.8+ Logger class, which is then passed
    # on to any new database connections made and which can be retrieved on both a class and instance level by calling +logger+.
    cattr_accessor :logger

    # Returns the connection currently associated with the class. This can
    # also be used to "borrow" the connection to do database work unrelated
    # to any of the specific Active Records. 
    def self.connection
      retrieve_connection
    end

    # Returns the connection currently associated with the class. This can
    # also be used to "borrow" the connection to do database work that isn't 
    # easily done without going straight to SQL. 
    def connection
      self.class.connection
    end

    def self.inherited(child) #:nodoc:
      @@subclasses[self] ||= []
      @@subclasses[self] << child
      super
    end

    @@subclasses = {}
    
    cattr_accessor :configurations
    @@primary_key_prefix_type = {}
    
    # Accessor for the prefix type that will be prepended to every primary key column name. The options are :table_name and 
    # :table_name_with_underscore. If the first is specified, the Product class will look for "productid" instead of "id" as
    # the primary column. If the latter is specified, the Product class will look for "product_id" instead of "id". Remember
    # that this is a global setting for all Active Records. 
    cattr_accessor :primary_key_prefix_type
    @@primary_key_prefix_type = nil

    # Accessor for the name of the prefix string to prepend to every table name. So if set to "basecamp_", all 
    # table names will be named like "basecamp_projects", "basecamp_people", etc. This is a convinient way of creating a namespace
    # for tables in a shared database. By default, the prefix is the empty string.
    cattr_accessor :table_name_prefix
    @@table_name_prefix = ""

    # Works like +table_name_prefix+, but appends instead of prepends (set to "_basecamp" gives "projects_basecamp",
    # "people_basecamp"). By default, the suffix is the empty string.
    cattr_accessor :table_name_suffix
    @@table_name_suffix = ""

    # Indicate whether or not table names should be the pluralized versions of the corresponding class names.
    # If true, this the default table name for a +Product+ class will be +products+. If false, it would just be +product+.
    # See table_name for the full rules on table/class naming. This is true, by default.
    cattr_accessor :pluralize_table_names
    @@pluralize_table_names = true

    # Determines whether to use Time.local (using :local) or Time.utc (using :utc) when pulling dates and times from the database.
    # This is set to :local by default.
    cattr_accessor :default_timezone
    @@default_timezone = :local

    class << self # Class methods
      # Returns objects for the records responding to either a specific id (1), a list of ids (1, 5, 6) or an array of ids. 
      # If only one ID is specified, that object is returned directly. If more than one ID is specified, an array is returned.
      # Examples:
      #   Person.find(1)       # returns the object for ID = 1
      #   Person.find(1, 2, 6) # returns an array for objects with IDs in (1, 2, 6)
      #   Person.find([7, 17]) # returns an array for objects with IDs in (7, 17)
      #   Person.find([1])     # returns an array for objects the object with ID = 1
      #
      # The last argument may be a Hash of find options.  Currently, +conditions+ is the only option, behaving the same as with +find_all+.
      #   Person.find(1, :conditions => "associate_id='5'"
      #   Person.find(1, 2, 6, :conditions => "status='active'"
      #   Person.find([7, 17], :conditions => ["sanitize_me='%s'", "bare'quote"]
      #
      # +RecordNotFound+ is raised if no record can be found.
      def find(*args)
        # Return an Array if ids are passed in an Array.
        expects_array = args.first.kind_of?(Array)

        # Extract options hash from argument list.
        options = extract_options_from_args!(args)
        conditions = " AND #{sanitize_sql(options[:conditions])}" if options[:conditions]

        ids = args.flatten.compact.uniq
        case ids.size

          # Raise if no ids passed.
          when 0
            raise RecordNotFound, "Couldn't find #{name} without an ID#{conditions}"

          # Find a single id.
          when 1
            unless result = find_first("#{primary_key} = #{sanitize(ids.first)}#{conditions}")
              raise RecordNotFound, "Couldn't find #{name} with ID=#{ids.first}#{conditions}"
            end

            # Box result if expecting array.
            expects_array ? [result] : result

          # Find multiple ids.
          else
            ids_list = ids.map { |id| sanitize(id) }.join(',')
            result   = find_all("#{primary_key} IN (#{ids_list})#{conditions}", primary_key)
            if result.size == ids.size
              result
            else
              raise RecordNotFound, "Couldn't find #{name} with ID in (#{ids_list})#{conditions}"
            end
        end
      end

      # This method is deprecated in favor of find with the :conditions option.
      # Works like find, but the record matching +id+ must also meet the +conditions+.
      # +RecordNotFound+ is raised if no record can be found matching the +id+ or meeting the condition.
      # Example:
      #   Person.find_on_conditions 5, "first_name LIKE '%dav%' AND last_name = 'heinemeier'"
      def find_on_conditions(ids, conditions)
        find(ids, :conditions => conditions)
      end

      # Returns an array of all the objects that could be instantiated from the associated
      # table in the database. The +conditions+ can be used to narrow the selection of objects (WHERE-part),
      # such as by "color = 'red'", and arrangement of the selection can be done through +orderings+ (ORDER BY-part),
      # such as by "last_name, first_name DESC". A maximum of returned objects and their offset can be specified in 
      # +limit+ (LIMIT...OFFSET-part). Examples:
      #   Project.find_all "category = 'accounts'", "last_accessed DESC", 15
      #   Project.find_all ["category = ?", category_name], "created ASC", ["? OFFSET ?", 15, 20]
      def find_all(conditions = nil, orderings = nil, limit = nil, joins = nil)
        sql  = "SELECT * FROM #{table_name} " 
        sql << "#{joins} " if joins
        add_conditions!(sql, conditions)
        sql << "ORDER BY #{orderings} " unless orderings.nil?

        connection.add_limit!(sql, sanitize_sql(limit)) unless limit.nil?

        find_by_sql(sql)
      end
  
      # Works like find_all, but requires a complete SQL string. Examples:
      #   Post.find_by_sql "SELECT p.*, c.author FROM posts p, comments c WHERE p.id = c.post_id"
      #   Post.find_by_sql ["SELECT * FROM posts WHERE author = ? AND created > ?", author_id, start_date]
      def find_by_sql(sql)
        connection.select_all(sanitize_sql(sql), "#{name} Load").inject([]) { |objects, record| objects << instantiate(record) }
      end
      
      # Returns the object for the first record responding to the conditions in +conditions+, 
      # such as "group = 'master'". If more than one record is returned from the query, it's the first that'll
      # be used to create the object. In such cases, it might be beneficial to also specify 
      # +orderings+, like "income DESC, name", to control exactly which record is to be used. Example: 
      #   Employee.find_first "income > 50000", "income DESC, name"
      def find_first(conditions = nil, orderings = nil)
        find_all(conditions, orderings, 1).first
      end
    
      # Creates an object, instantly saves it as a record (if the validation permits it), and returns it. If the save
      # fail under validations, the unsaved object is still returned.
      def create(attributes = nil)
        object = new(attributes)
        object.save
        object
      end

      # Finds the record from the passed +id+, instantly saves it with the passed +attributes+ (if the validation permits it), 
      # and returns it. If the save fail under validations, the unsaved object is still returned.
      def update(id, attributes)
        object = find(id)
        object.attributes = attributes
        object.save
        object
      end

      # Deletes the record with the given +id+ without instantiating an object first.
      def delete(id)
        delete_all([ "#{primary_key} = ?", id ])
      end
      
      # Destroys the record with the given +id+ by instantiating the object and calling #destroy (all the callbacks are the triggered).
      def destroy(id)
        find(id).destroy
      end

      # Updates all records with the SET-part of an SQL update statement in +updates+ and returns an integer with the number of rows updates.
      # A subset of the records can be selected by specifying +conditions+. Example:
      #   Billing.update_all "category = 'authorized', approved = 1", "author = 'David'"
      def update_all(updates, conditions = nil)
        sql  = "UPDATE #{table_name} SET #{updates} "
        add_conditions!(sql, conditions)
        return connection.update(sql, "#{name} Update")
      end
    
      # Destroys the objects for all the records that matches the +condition+ by instantiating each object and calling
      # the destroy method. Example:
      #   Person.destroy_all "last_login < '2004-04-04'"
      def destroy_all(conditions = nil)
        find_all(conditions).each { |object| object.destroy }
      end
    
      # Deletes all the records that matches the +condition+ without instantiating the objects first (and hence not 
      # calling the destroy method). Example:
      #   Post.destroy_all "person_id = 5 AND (category = 'Something' OR category = 'Else')"
      def delete_all(conditions = nil)
        sql = "DELETE FROM #{table_name} "
        add_conditions!(sql, conditions)
        connection.delete(sql, "#{name} Delete all")
      end
    
      # Returns the number of records that meets the +conditions+. Zero is returned if no records match. Example:
      #   Product.count "sales > 1"
      def count(conditions = nil)
        sql  = "SELECT COUNT(*) FROM #{table_name} "
        add_conditions!(sql, conditions)
        count_by_sql(sql)
      end

      # Returns the result of an SQL statement that should only include a COUNT(*) in the SELECT part.
      #   Product.count "SELECT COUNT(*) FROM sales s, customers c WHERE s.customer_id = c.id"
      def count_by_sql(sql)
        sql = sanitize_conditions(sql)
        count = connection.select_one(sql, "#{name} Count").values.first
        return count ? count.to_i : 0
      end
        
      # Increments the specified counter by one. So <tt>DiscussionBoard.increment_counter("post_count", 
      # discussion_board_id)</tt> would increment the "post_count" counter on the board responding to discussion_board_id.
      # This is used for caching aggregate values, so that they doesn't need to be computed every time. Especially important
      # for looping over a collection where each element require a number of aggregate values. Like the DiscussionBoard
      # that needs to list both the number of posts and comments.
      def increment_counter(counter_name, id)
        update_all "#{counter_name} = #{counter_name} + 1", "#{primary_key} = #{quote(id)}"
      end

      # Works like increment_counter, but decrements instead.
      def decrement_counter(counter_name, id)
        update_all "#{counter_name} = #{counter_name} - 1", "#{primary_key} = #{quote(id)}"
      end

      # Attributes named in this macro are protected from mass-assignment, such as <tt>new(attributes)</tt> and 
      # <tt>attributes=(attributes)</tt>. Their assignment will simply be ignored. Instead, you can use the direct writer
      # methods to do assignment. This is meant to protect sensitive attributes to be overwritten by URL/form hackers. Example:
      #
      #   class Customer < ActiveRecord::Base
      #     attr_protected :credit_rating
      #   end
      #
      #   customer = Customer.new("name" => David, "credit_rating" => "Excellent")
      #   customer.credit_rating # => nil
      #   customer.attributes = { "description" => "Jolly fellow", "credit_rating" => "Superb" }
      #   customer.credit_rating # => nil
      #
      #   customer.credit_rating = "Average"
      #   customer.credit_rating # => "Average"
      def attr_protected(*attributes)
        write_inheritable_array("attr_protected", attributes)
      end
      
      # Returns an array of all the attributes that have been protected from mass-assigment.
      def protected_attributes # :nodoc:
        read_inheritable_attribute("attr_protected")
      end

      # If this macro is used, only those attributed named in it will be accessible for mass-assignment, such as 
      # <tt>new(attributes)</tt> and <tt>attributes=(attributes)</tt>. This is the more conservative choice for mass-assignment
      # protection. If you'd rather start from an all-open default and restrict attributes as needed, have a look at
      # attr_protected.
      def attr_accessible(*attributes)
        write_inheritable_array("attr_accessible", attributes)
      end
      
      # Returns an array of all the attributes that have been made accessible to mass-assigment.
      def accessible_attributes # :nodoc:
        read_inheritable_attribute("attr_accessible")
      end

      # Specifies that the attribute by the name of +attr_name+ should be serialized before saving to the database and unserialized
      # after loading from the database. The serialization is done through YAML. If +class_name+ is specified, the serialized
      # object must be of that class on retrival or +SerializationTypeMismatch+ will be raised.
      def serialize(attr_name, class_name = Object)
        write_inheritable_attribute("attr_serialized", serialized_attributes.update(attr_name.to_s => class_name))
      end
      
      # Returns a hash of all the attributes that have been specified for serialization as keys and their class restriction as values.
      def serialized_attributes
        read_inheritable_attribute("attr_serialized") || { }
      end

      # Guesses the table name (in forced lower-case) based on the name of the class in the inheritance hierarchy descending
      # directly from ActiveRecord. So if the hierarchy looks like: Reply < Message < ActiveRecord, then Message is used
      # to guess the table name from even when called on Reply. The guessing rules are as follows:
      #
      # * Class name ends in "x", "ch" or "ss": "es" is appended, so a Search class becomes a searches table.
      # * Class name ends in "y" preceded by a consonant or "qu": The "y" is replaced with "ies", so a Category class becomes a categories table. 
      # * Class name ends in "fe": The "fe" is replaced with "ves", so a Wife class becomes a wives table.
      # * Class name ends in "lf" or "rf": The "f" is replaced with "ves", so a Half class becomes a halves table.
      # * Class name ends in "person": The "person" is replaced with "people", so a Salesperson class becomes a salespeople table.
      # * Class name ends in "man": The "man" is replaced with "men", so a Spokesman class becomes a spokesmen table.
      # * Class name ends in "sis": The "i" is replaced with an "e", so a Basis class becomes a bases table.
      # * Class name ends in "tum" or "ium": The "um" is replaced with an "a", so a Datum class becomes a data table.
      # * Class name ends in "child": The "child" is replaced with "children", so a NodeChild class becomes a node_children table.
      # * Class name ends in an "s": No additional characters are added or removed.
      # * Class name doesn't end in "s": An "s" is appended, so a Comment class becomes a comments table.
      # * Class name with word compositions: Compositions are underscored, so CreditCard class becomes a credit_cards table.
      #
      # Additionally, the class-level table_name_prefix is prepended to the table_name and the table_name_suffix is appended.
      # So if you have "myapp_" as a prefix, the table name guess for an Account class becomes "myapp_accounts".
      #
      # You can also overwrite this class method to allow for unguessable links, such as a Mouse class with a link to a
      # "mice" table. Example:
      #
      #   class Mouse < ActiveRecord::Base
      #      def self.table_name() "mice" end
      #   end
      def table_name
        table_name_prefix + undecorated_table_name(class_name_of_active_record_descendant(self)) + table_name_suffix
      end

      # Defines the primary key field -- can be overridden in subclasses. Overwritting will negate any effect of the
      # primary_key_prefix_type setting, though.
      def primary_key
        case primary_key_prefix_type
          when :table_name
            Inflector.foreign_key(class_name_of_active_record_descendant(self), false)
          when :table_name_with_underscore
            Inflector.foreign_key(class_name_of_active_record_descendant(self))
          else
            "id"
        end
      end

      # Defines the column name for use with single table inheritance -- can be overridden in subclasses.
      def inheritance_column
        "type"
      end

      # Turns the +table_name+ back into a class name following the reverse rules of +table_name+.
      def class_name(table_name = table_name) # :nodoc:
        # remove any prefix and/or suffix from the table name
        class_name = Inflector.camelize(table_name[table_name_prefix.length..-(table_name_suffix.length + 1)])
        class_name = Inflector.singularize(class_name) if pluralize_table_names
        return class_name
      end

      # Returns an array of column objects for the table associated with this class.
      def columns
        @columns ||= connection.columns(table_name, "#{name} Columns")
      end
      
      # Returns an array of column objects for the table associated with this class.
      def columns_hash
        @columns_hash ||= columns.inject({}) { |hash, column| hash[column.name] = column; hash }
      end

      # Returns an array of columns objects where the primary id, all columns ending in "_id" or "_count", 
      # and columns used for single table inheritance has been removed.
      def content_columns
        @content_columns ||= columns.reject { |c| c.name == primary_key || c.name =~ /(_id|_count)$/ || c.name == inheritance_column }
      end

      # Returns a hash of all the methods added to query each of the columns in the table with the name of the method as the key
      # and true as the value. This makes it possible to do O(1) lookups in respond_to? to check if a given method for attribute
      # is available. 
      def column_methods_hash
        @dynamic_methods_hash ||= columns_hash.keys.inject(Hash.new(false)) do |methods, attr|
          methods[attr.to_sym]       = true
          methods["#{attr}=".to_sym] = true
          methods["#{attr}?".to_sym] = true
          methods["#{attr}_before_type_cast".to_sym] = true
          methods
        end
      end
      
      # Resets all the cached information about columns, which will cause they to be reloaded on the next request.
      def reset_column_information
        @columns = @columns_hash = @content_columns = @dynamic_methods_hash = nil
      end

      def reset_column_information_and_inheritable_attributes_for_all_subclasses
        subclasses.each { |klass| klass.reset_inheritable_attributes; klass.reset_column_information }
      end

      # Transforms attribute key names into a more humane format, such as "First name" instead of "first_name". Example:
      #   Person.human_attribute_name("first_name") # => "First name"
      def human_attribute_name(attribute_key_name)
        attribute_key_name.gsub(/_/, " ").capitalize unless attribute_key_name.nil?
      end
      
      def descends_from_active_record? # :nodoc:
        superclass == Base || !columns_hash.has_key?(inheritance_column)
      end

      def quote(object)
        connection.quote(object)
      end

      # Used to sanitize objects before they're used in an SELECT SQL-statement. Delegates to <tt>connection.quote</tt>.
      def sanitize(object) # :nodoc:
        connection.quote(object)
      end

      # Used to aggregate logging and benchmark, so you can measure and represent multiple statements in a single block.
      # Usage (hides all the SQL calls for the individual actions and calculates total runtime for them all):
      #
      #   Project.benchmark("Creating project") do
      #     project = Project.create("name" => "stuff")
      #     project.create_manager("name" => "David")
      #     project.milestones << Milestone.find_all
      #   end
      def benchmark(title)
        result = nil
        logger.level = Logger::ERROR
        bm = Benchmark.measure { result = yield }
        logger.level = Logger::DEBUG
        logger.info "#{title} (#{sprintf("%f", bm.real)})"
        return result
      end

      private
        # Finder methods must instantiate through this method to work with the single-table inheritance model
        # that makes it possible to create objects of different types from the same table.
        def instantiate(record)
          require_association_class(record[inheritance_column])

          begin
            object = record_with_type?(record) ? compute_type(record[inheritance_column]).allocate : allocate
          rescue NameError
            raise(
              SubclassNotFound, 
              "The single-table inheritance mechanism failed to locate the subclass: '#{record[inheritance_column]}'. " +
              "This error is raised because the column '#{inheritance_column}' is reserved for storing the class in case of inheritance. " +
              "Please rename this column if you didn't intend it to be used for storing the inheritance class " +
              "or overwrite #{self.to_s}.inheritance_column to use another column for that information."
            )
          end

          object.instance_variable_set("@attributes", record)
          return object
        end
        
        # Returns true if the +record+ has a single table inheritance column and is using it.
        def record_with_type?(record)
          record.include?(inheritance_column) && !record[inheritance_column].nil? && 
            !record[inheritance_column].empty?
        end
        
        # Returns the name of the type of the record using the current module as a prefix. So descendents of
        # MyApp::Business::Account would be appear as "MyApp::Business::AccountSubclass".
        def type_name_with_module(type_name)
          self.name =~ /::/ ? self.name.scan(/(.*)::/).first.first + "::" + type_name : type_name
        end

        # Adds a sanitized version of +conditions+ to the +sql+ string. Note that it's the passed +sql+ string is changed.
        def add_conditions!(sql, conditions)
          sql << "WHERE #{sanitize_sql(conditions)} " unless conditions.nil?
          sql << (conditions.nil? ? "WHERE " : " AND ") + type_condition unless descends_from_active_record?
        end
        
        def type_condition
          " (" + subclasses.inject("#{inheritance_column} = '#{Inflector.demodulize(name)}' ") do |condition, subclass| 
            condition << "OR #{inheritance_column} = '#{Inflector.demodulize(subclass.name)}' "
          end + ") "
        end

        # Guesses the table name, but does not decorate it with prefix and suffix information.
        def undecorated_table_name(class_name = class_name_of_active_record_descendant(self))
          table_name = Inflector.underscore(Inflector.demodulize(class_name))
          table_name = Inflector.pluralize(table_name) if pluralize_table_names
          return table_name
        end

        # Enables dynamic finders like find_by_user_name(user_name) and find_by_user_name_and_password(user_name, password) that are turned into 
        # find_first(["user_name = ?", user_name]) and find_first(["user_name = ? AND password = ?", user_name, password]) respectively. Also works
        # for find_all, but using find_all_by_amount(50) that are turned into find_all(["amount = ?", 50]).
        def method_missing(method_id, *arguments)
          method_name = method_id.id2name

          if method_name =~ /find_(all_by|by)_([_a-z]+)/
            finder, attributes = ($1 == "all_by" ? :find_all : :find_first), $2.split("_and_")
            attributes.each { |attr_name| super unless column_methods_hash[attr_name.intern] }
            conditions = attributes.collect { |attr_name| "#{attr_name} = ? "}.join(" AND ")
            send(finder, [conditions, *arguments])
          else
            super
          end
        end

      protected
        def subclasses
          @@subclasses[self] ||= []
          @@subclasses[self] + extra = @@subclasses[self].inject([]) {|list, subclass| list + subclass.subclasses }
        end
      
        # Returns the class type of the record using the current module as a prefix. So descendents of
        # MyApp::Business::Account would be appear as MyApp::Business::AccountSubclass.
        def compute_type(type_name)
          type_name_with_module(type_name).split("::").inject(Object) do |final_type, part| 
            final_type = final_type.const_get(part)
          end
        end

        # Returns the name of the class descending directly from ActiveRecord in the inheritance hierarchy.
        def class_name_of_active_record_descendant(klass)
          if klass.superclass == Base
            return klass.name
          elsif klass.superclass.nil?
            raise ActiveRecordError, "#{name} doesn't belong in a hierarchy descending from ActiveRecord"
          else
            class_name_of_active_record_descendant(klass.superclass)
          end
        end

        # Accepts an array or string.  The string is returned untouched, but the array has each value
        # sanitized and interpolated into the sql statement.
        #   ["name='%s' and group_id='%s'", "foo'bar", 4]  returns  "name='foo''bar' and group_id='4'"
        def sanitize_sql(ary)
          return ary unless ary.is_a?(Array)

          statement, *values = ary
          if values.first.is_a?(Hash) and statement =~ /:\w+/
            replace_named_bind_variables(statement, values.first)
          elsif statement.include?('?')
            replace_bind_variables(statement, values)
          else
            statement % values.collect { |value| connection.quote_string(value.to_s) }
          end
        end

        alias_method :sanitize_conditions, :sanitize_sql

        def replace_bind_variables(statement, values)
          raise_if_bind_arity_mismatch(statement, statement.count('?'), values.size)
          bound = values.dup
          statement.gsub('?') { connection.quote(bound.shift) }
        end

        def replace_named_bind_variables(statement, bind_vars)
          raise_if_bind_arity_mismatch(statement, statement.scan(/:(\w+)/).uniq.size, bind_vars.size)
          statement.gsub(/:(\w+)/) do
            match = $1.to_sym
            if bind_vars.has_key?(match)
              connection.quote(bind_vars[match])
            else
              raise PreparedStatementInvalid, "missing value for :#{match} in #{statement}"
            end
          end
        end

        def raise_if_bind_arity_mismatch(statement, expected, provided)
          unless expected == provided
            raise PreparedStatementInvalid, "wrong number of bind variables (#{provided} for #{expected}) in: #{statement}"
          end
        end

        def extract_options_from_args!(args)
          if args.last.is_a?(Hash) then args.pop else {} end
        end
        
        def encode_quoted_value(value)
          quoted_value = connection.quote(value)
          quoted_value = "'#{quoted_value[1..-2].gsub(/\'/, "\\\\'")}'" if quoted_value.include?("\\\'")          
          quoted_value
        end
    end

    public
      # New objects can be instantiated as either empty (pass no construction parameter) or pre-set with
      # attributes but not yet saved (pass a hash with key names matching the associated table column names).
      # In both instances, valid attribute keys are determined by the column names of the associated table -- 
      # hence you can't have attributes that aren't part of the table columns.
      def initialize(attributes = nil)
        @attributes = attributes_from_column_definition
        @new_record = true
        ensure_proper_type
        self.attributes = attributes unless attributes.nil?
        yield self if block_given?
      end
      
      # Every Active Record class must use "id" as their primary ID. This getter overwrites the native
      # id method, which isn't being used in this context.
      def id
        read_attribute(self.class.primary_key)
      end
      
      def id_before_type_cast
        read_attribute_before_type_cast(self.class.primary_key)
      end

      def quoted_id
        quote(id, self.class.columns_hash[self.class.primary_key])
      end
      
      # Sets the primary ID.
      def id=(value)
        write_attribute(self.class.primary_key, value)
      end
      
      # Returns true if this object hasn't been saved yet -- that is, a record for the object doesn't exist yet.
      def new_record?
        @new_record
      end
      
      # * No record exists: Creates a new record with values matching those of the object attributes.
      # * A record does exist: Updates the record with values matching those of the object attributes.
      def save
        create_or_update
        return true
      end
    
      # Deletes the record in the database and freezes this instance to reflect that no changes should
      # be made (since they can't be persisted).
      def destroy
        unless new_record?
          connection.delete(
            "DELETE FROM #{self.class.table_name} " + 
            "WHERE #{self.class.primary_key} = #{quote(id)}", 
            "#{self.class.name} Destroy"
          )
        end

        freeze
      end

      # Returns a clone of the record that hasn't been assigned an id yet and is treated as a new record.
      def clone
        attr = Hash.new

        self.attribute_names.each do |name|
          begin
            attr[name] = read_attribute(name).clone
          rescue TypeError
            attr[name] = read_attribute(name)
          end
        end

        cloned_record = self.class.new(attr)
        cloned_record.instance_variable_set "@new_record", true
        cloned_record.id = nil
        cloned_record
      end
            
      # Updates a single attribute and saves the record. This is especially useful for boolean flags on existing records.
      # Note: This method is overwritten by the Validation module that'll make sure that updates made with this method
      # doesn't get subjected to validation checks. Hence, attributes can be updated even if the full object isn't valid.
      def update_attribute(name, value)
        self[name] = value
        return true
      end

      # Updates all the attributes in from the passed hash and saves the record. If the object is invalid, the saving will
      # fail and false will be returned.
      def update_attributes(attributes)
        self.attributes = attributes
        return save
      end

      # Returns the value of attribute identified by <tt>attr_name</tt> after it has been type cast (for example, 
      # "2004-12-12" in a data column is cast to a date object, like Date.new(2004, 12, 12)).
      # (Alias for the protected read_attribute method).
      def [](attr_name) 
        read_attribute(attr_name)
      end
      
      # Updates the attribute identified by <tt>attr_name</tt> with the specified +value+.
      # (Alias for the protected write_attribute method).
      def []= (attr_name, value) 
        write_attribute(attr_name, value)
      end

      # Allows you to set all the attributes at once by passing in a hash with keys
      # matching the attribute names (which again matches the column names). Sensitive attributes can be protected
      # from this form of mass-assignment by using the +attr_protected+ macro. Or you can alternatively
      # specify which attributes *can* be accessed in with the +attr_accessible+ macro. Then all the
      # attributes not included in that won't be allowed to be mass-assigned.
      def attributes=(attributes)
        return if attributes.nil?

        multi_parameter_attributes = []
        remove_attributes_protected_from_mass_assignment(attributes).each do |k, v| 
          k.include?("(") ? multi_parameter_attributes << [ k, v ] : send(k + "=", v)
        end
        assign_multiparameter_attributes(multi_parameter_attributes)
      end

      # Returns true if the specified +attribute+ has been set by the user or by a database load and is neither
      # nil nor empty? (the latter only applies to objects that responds to empty?, most notably Strings).
      def attribute_present?(attribute)
        is_empty = read_attribute(attribute).respond_to?("empty?") ? read_attribute(attribute).empty? : false
        @attributes.include?(attribute) && !@attributes[attribute].nil? && !is_empty
      end

      # Returns an array of names for the attributes available on this object sorted alphabetically.
      def attribute_names
        @attributes.keys.sort
      end

      # Returns the column object for the named attribute.
      def column_for_attribute(name)
        self.class.columns_hash[name]
      end
            
      # Returns true if the +comparison_object+ is of the same type and has the same id.
      def ==(comparison_object)
        comparison_object.instance_of?(self.class) && comparison_object.id == id
      end

      # Delegates to ==
      def eql?(comparison_object)
        self == (comparison_object)
      end
      
      # Delegates to id in order to allow two records of the same type and id to work with something like:
      #   [ Person.find(1), Person.find(2), Person.find(3) ] & [ Person.find(1), Person.find(4) ] # => [ Person.find(1) ]
      def hash
        id
      end

      # For checking respond_to? without searching the attributes (which is faster).
      alias_method :respond_to_without_attributes?, :respond_to?

      # A Person object with a name attribute can ask person.respond_to?("name"), person.respond_to?("name="), and
      # person.respond_to?("name?") which will all return true.
      def respond_to?(method)
        self.class.column_methods_hash[method.to_sym] || respond_to_without_attributes?(method)
      end
      
    private
      def create_or_update
        if new_record? then create else update end
      end

      # Updates the associated record with values matching those of the instant attributes.
      def update
        connection.update(
          "UPDATE #{self.class.table_name} " +
          "SET #{quoted_comma_pair_list(connection, attributes_with_quotes(false))} " +
          "WHERE #{self.class.primary_key} = #{quote(id)}",
          "#{self.class.name} Update"
        )
      end

      # Creates a new record with values matching those of the instant attributes.
      def create
        self.id = connection.insert(
          "INSERT INTO #{self.class.table_name} " +
          "(#{quoted_column_names.join(', ')}) " +
          "VALUES(#{attributes_with_quotes.values.join(', ')})",
          "#{self.class.name} Create",
          self.class.primary_key, self.id
        )
        
        @new_record = false
      end

      # Sets the attribute used for single table inheritance to this class name if this is not the ActiveRecord descendant. 
      # Considering the hierarchy Reply < Message < ActiveRecord, this makes it possible to do Reply.new without having to 
      # set Reply[Reply.inheritance_column] = "Reply" yourself. No such attribute would be set for objects of the 
      # Message class in that example.
      def ensure_proper_type
        unless self.class.descends_from_active_record?
          write_attribute(self.class.inheritance_column, Inflector.demodulize(self.class.name))
        end
      end

      # Allows access to the object attributes, which are held in the @attributes hash, as were
      # they first-class methods. So a Person class with a name attribute can use Person#name and
      # Person#name= and never directly use the attributes hash -- except for multiple assigns with
      # ActiveRecord#attributes=. A Milestone class can also ask Milestone#completed? to test that
      # the completed attribute is not nil or 0. 
      #
      # It's also possible to instantiate related objects, so a Client class belonging to the clients
      # table with a master_id foreign key can instantiate master through Client#master.
      def method_missing(method_id, *arguments)
        method_name = method_id.id2name

        if method_name =~ read_method? && @attributes.include?($1)
          return read_attribute($1)
        elsif method_name =~ read_untyped_method? && @attributes.include?($1)
          return read_attribute_before_type_cast($1)
        elsif method_name =~ write_method? && @attributes.include?($1)
          write_attribute($1, arguments[0])
        elsif method_name =~ query_method? && @attributes.include?($1)
          return query_attribute($1)
        else
          super
        end
      end

      def read_method?()         /^([a-zA-Z][-_\w]*)[^=?]*$/ end
      def read_untyped_method?() /^([a-zA-Z][-_\w]*)_before_type_cast$/ end
      def write_method?()        /^([a-zA-Z][-_\w]*)=.*$/    end
      def query_method?()        /^([a-zA-Z][-_\w]*)\?$/     end

      # Returns the value of attribute identified by <tt>attr_name</tt> after it has been type cast (for example,
      # "2004-12-12" in a data column is cast to a date object, like Date.new(2004, 12, 12)).
      def read_attribute(attr_name) #:doc:
        if @attributes.keys.include? attr_name
          if column = column_for_attribute(attr_name)
            unserializable_attribute?(attr_name, column) ?
              unserialize_attribute(attr_name) : column.type_cast(@attributes[attr_name])
          else
            @attributes[attr_name]
          end
        else
          nil
        end
      end

      def read_attribute_before_type_cast(attr_name)
        @attributes[attr_name]
      end

      # Returns true if the attribute is of a text column and marked for serialization.
      def unserializable_attribute?(attr_name, column)
        @attributes[attr_name] && [:text, :string].include?(column.send(:type)) && @attributes[attr_name].is_a?(String) && self.class.serialized_attributes[attr_name]
      end

      # Returns the unserialized object of the attribute.
      def unserialize_attribute(attr_name)
        unserialized_object = object_from_yaml(@attributes[attr_name])

        if unserialized_object.is_a?(self.class.serialized_attributes[attr_name])
          @attributes[attr_name] = unserialized_object
        else
          raise(
            SerializationTypeMismatch, 
            "#{attr_name} was supposed to be a #{self.class.serialized_attributes[attr_name]}, " +
            "but was a #{unserialized_object.class.to_s}"
          )
        end
      end

      # Updates the attribute identified by <tt>attr_name</tt> with the specified +value+. Empty strings for fixnum and float
      # columns are turned into nil.
      def write_attribute(attr_name, value) #:doc:
        @attributes[attr_name] = empty_string_for_number_column?(attr_name, value) ? nil : value
      end

      def empty_string_for_number_column?(attr_name, value)
        column = column_for_attribute(attr_name)
        column && (column.klass == Fixnum || column.klass == Float) && value == ""
      end

      def query_attribute(attr_name)
        attribute = @attributes[attr_name]
        if attribute.kind_of?(Fixnum) && attribute == 0
          false
        elsif attribute.kind_of?(String) && attribute == "0"
          false
        elsif attribute.kind_of?(String) && attribute.empty?
          false
        elsif attribute.nil?
          false
        elsif attribute == false
          false
        elsif attribute == "f"
          false
        elsif attribute == "false"
          false
        else
          true
        end
      end

      def remove_attributes_protected_from_mass_assignment(attributes)
        if self.class.accessible_attributes.nil? && self.class.protected_attributes.nil?
          attributes.reject { |key, value| key == self.class.primary_key }
        elsif self.class.protected_attributes.nil?
          attributes.reject { |key, value| !self.class.accessible_attributes.include?(key.intern) || key == self.class.primary_key }
        elsif self.class.accessible_attributes.nil?
          attributes.reject { |key, value| self.class.protected_attributes.include?(key.intern) || key == self.class.primary_key }
        end
      end

      # Returns copy of the attributes hash where all the values have been safely quoted for use in
      # an SQL statement. 
      def attributes_with_quotes(include_primary_key = true)
        columns_hash = self.class.columns_hash
        @attributes.inject({}) do |attrs_quoted, pair| 
          attrs_quoted[pair.first] = quote(pair.last, columns_hash[pair.first]) unless !include_primary_key && pair.first == self.class.primary_key
          attrs_quoted
        end
      end
      
      # Quote strings appropriately for SQL statements.
      def quote(value, column = nil)
        connection.quote(value, column)
      end

      # Interpolate custom sql string in instance context.
      # Optional record argument is meant for custom insert_sql.
      def interpolate_sql(sql, record = nil)
        instance_eval("%(#{sql})")
      end

      # Initializes the attributes array with keys matching the columns from the linked table and
      # the values matching the corresponding default value of that column, so
      # that a new instance, or one populated from a passed-in Hash, still has all the attributes
      # that instances loaded from the database would.
      def attributes_from_column_definition
        connection.columns(self.class.table_name, "#{self.class.name} Columns").inject({}) do |attributes, column| 
          attributes[column.name] = column.default unless column.name == self.class.primary_key
          attributes
        end
      end

      # Instantiates objects for all attribute classes that needs more than one constructor parameter. This is done
      # by calling new on the column type or aggregation type (through composed_of) object with these parameters.
      # So having the pairs written_on(1) = "2004", written_on(2) = "6", written_on(3) = "24", will instantiate
      # written_on (a date type) with Date.new("2004", "6", "24"). You can also specify a typecast character in the
      # parenteses to have the parameters typecasted before they're used in the constructor. Use i for Fixnum, f for Float,
      # s for String, and a for Array. If all the values for a given attribute is empty, the attribute will be set to nil.
      def assign_multiparameter_attributes(pairs)
        execute_callstack_for_multiparameter_attributes(
          extract_callstack_for_multiparameter_attributes(pairs)
        )
      end
      
      # Includes an ugly hack for Time.local instead of Time.new because the latter is reserved by Time itself.
      def execute_callstack_for_multiparameter_attributes(callstack)
        callstack.each do |name, values|
          klass = (self.class.reflect_on_aggregation(name) || column_for_attribute(name)).klass
          if values.empty?
            send(name + "=", nil)
          else
            send(name + "=", Time == klass ? klass.local(*values) : klass.new(*values))
          end
        end
      end
      
      def extract_callstack_for_multiparameter_attributes(pairs)
        attributes = { }

        for pair in pairs
          multiparameter_name, value = pair
          attribute_name = multiparameter_name.split("(").first
          attributes[attribute_name] = [] unless attributes.include?(attribute_name)

          unless value.empty?
            attributes[attribute_name] << 
              [find_parameter_position(multiparameter_name), type_cast_attribute_value(multiparameter_name, value)]
          end
        end

        attributes.each { |name, values| attributes[name] = values.sort_by{ |v| v.first }.collect { |v| v.last } }
      end
      
      def type_cast_attribute_value(multiparameter_name, value)
        multiparameter_name =~ /\([0-9]*([a-z])\)/ ? value.send("to_" + $1) : value
      end
      
      def find_parameter_position(multiparameter_name)
        multiparameter_name.scan(/\(([0-9]*).*\)/).first.first
      end
      
      # Returns a comma-separated pair list, like "key1 = val1, key2 = val2".
      def comma_pair_list(hash)
        hash.inject([]) { |list, pair| list << "#{pair.first} = #{pair.last}" }.join(", ")
      end

      def quoted_column_names(attributes = attributes_with_quotes)
        attributes.keys.collect { |column_name| connection.quote_column_name(column_name) }
      end

      def quote_columns(column_quoter, hash)
        hash.inject({}) {|list, pair|
          list[column_quoter.quote_column_name(pair.first)] = pair.last
          list
        }
      end

      def quoted_comma_pair_list(column_quoter, hash)
        comma_pair_list(quote_columns(column_quoter, hash))
      end

      def object_from_yaml(string)
        return string unless String === string
        if has_yaml_encoding_header?(string)
          begin
            YAML::load(string)
          rescue Object
            # Apparently wasn't YAML anyway
            string
          end
        else
          string
        end
      end

      def has_yaml_encoding_header?(string)
        string[0..3] == "--- "
      end
  end
end
