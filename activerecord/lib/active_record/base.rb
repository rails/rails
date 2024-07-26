require 'active_record/support/class_attribute_accessors'
require 'active_record/support/class_inheritable_attributes'
require 'yaml'

module ActiveRecord #:nodoc:
  class ActiveRecordError < Exception #:nodoc:
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
  #     def authenticate_unsafely(user_name, password)
  #       find_first("user_name = '#{user_name}' AND password = '#{password}'")
  #     end
  # 
  #     def authenticate_safely(user_name, password)
  #       find_first([ "user_name = '%s' AND password = '%s'", user_name, password ])
  #     end
  #   end
  # 
  # The +authenticate_unsafely+ method inserts the parameters directly into the query and is thus susceptible to SQL-injection
  # attacks if the +user_name+ and +password+ parameters come directly from a HTTP request. The +authenticate_safely+ method, on
  # the other hand, will sanitize the +user_name+ and +password+ before inserting them in the query, which will ensure that
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
  # == Saving arrays, hashes, and other non-mappeable objects in text columns
  # 
  # Active Record will automatically attempt to serialize (using YAML) any object in text columns that isn't either a String,
  # NilClass, TrueClass, FalseClass, Fixnum, Date, or Time. This makes it possible to store arrays, hashes, and other
  # non-mappeable objects without doing any additional work. Example:
  # 
  #    user = User.find(1)
  #    user.preferences = { "background" => "black", "display" => large }
  #    user.save
  #    
  #    User.find(1).preferences # => { "background" => "black", "display" => large }
  # 
  # == Exceptions
  # 
  # * +ActiveRecordError+ -- generic error class and superclass of all other errors raised by Active Record
  # * +AdapterNotSpecified+ -- the configuration hash used in <tt>establish_connection</tt> didn't include a 
  #   <tt>:adapter</tt> key.
  # * +AdapterNotSpecified+ -- the <tt>:adapter</tt> key used in <tt>establish_connection</tt> specified an unexisting adapter
  #   (or a bad spelling of an existing one). 
  #   <tt>:adapter</tt> key.
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

    # Returns the connection currently held by the class. This can be used to "borrow" the connection to do database
    # work unrelated to any of the specific Active Records. Use *_connection methods to establish the connection in 
    # the first place.
    cattr_accessor :connection
    def self.connection #:nodoc:
      Thread.current['connection'] ||= retrieve_connection
      Thread.current['connection']
    end
    
    def self.connected?
      !Thread.current['connection'].nil?
    end 

    # Accessor for the prefix type that will be prepended to every primary key column name. The options are :table_name and 
    # :table_name_with_underscore. If the first is specified, the Product class will look for "productid" instead of "id" as
    # the primary column. If the latter is specified, the Product class will look for "product_id" instead of "id". Remember
    # that this is a global setting for all Active Records. 
    cattr_accessor :primary_key_prefix_type
    @@primary_key_prefix = nil

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

    class << self # Class methods
      # Returns objects for the records responding to either a specific id (1), a list of ids (1, 5, 6) or an array of ids. 
      # If only one ID is specified, that object is returned directly. If more than one ID is specified, an array is returned.
      # Examples:
      #   Person.find(1)       # returns the object for ID = 1
      #   Person.find(1, 2, 6) # returns an array for objects with IDs in (1, 2, 6)
      #   Person.find([7, 17]) # returns an array for objects with IDs in (7, 17)
      # +RecordNotFound+ is raised if no record can be found.
      def find(*ids)
        ids = [ ids ].flatten.compact

        if ids.length > 1
          ids_list = ids.map{ |id| "'#{id}'" }.join(", ")
          objects  = find_all("#{primary_key} IN (#{ids_list})", primary_key)

          if objects.length == ids.length
            return objects
          else
            raise RecordNotFound, "Couldn't find #{name} with ID in (#{ids_list})"
          end
        elsif ids.length == 1
          id = ids.first
          sql = "SELECT * FROM #{table_name} WHERE #{primary_key} = '#{id}'"
          sql << "AND type = '#{name.gsub(/.*::/, '')}'" unless descents_from_active_record?

          if record = connection.select_one(sql, "#{name} Find")
            instantiate(record)
          else 
            raise RecordNotFound, "Couldn't find #{name} with ID = #{id}"
          end
        else
          raise RecordNotFound, "Couldn't find #{name} without an ID"
        end
      end

      # Works like find, but the record matching +id+ must also meet the +conditions+.
      # +RecordNotFound+ is raised if no record can be found matching the +id+ or meeting the condition.
      # Example:
      #   Person.find_on_conditions 5, "first_name LIKE '%dav%' AND last_name = 'heinemeier'"
      def find_on_conditions(id, conditions)
        find_first("#{primary_key} = '#{id}' AND #{sanitize_conditions(conditions)}") || 
            raise(RecordNotFound, "Couldn't find #{name} with #{primary_key} = #{id} on the condition of #{conditions}")
      end
    
      # Returns an array of all the objects that could be instantiated from the associated
      # table in the database. The +conditions+ can be used to narrow the selection of objects (WHERE-part),
      # such as by "color = 'red'", and arrangement of the selection can be done through +orderings+ (ORDER BY-part),
      # such as by "last_name, first_name DESC". A maximum of returned objects can be specified in +limit+. Example:
      #   Project.find_all "category = 'accounts'", "last_accessed DESC", 15
      def find_all(conditions = nil, orderings = nil, limit = nil, joins = nil)
        sql  = "SELECT * FROM #{table_name} " 
        sql << "#{joins} " if joins
        add_conditions!(sql, conditions)
        sql << "ORDER BY #{orderings} " unless orderings.nil?
        sql << "LIMIT #{limit} " unless limit.nil?
    
        find_by_sql(sql)
      end
  
      # Works like find_all, but requires a complete SQL string. Example:
      #   Post.find_by_sql "SELECT p.*, c.author FROM posts p, comments c WHERE p.id = c.post_id"
      def find_by_sql(sql)
        connection.select_all(sql, "#{name} Load").inject([]) { |objects, record| objects << instantiate(record) }
      end
    
      # Returns the object for the first record responding to the conditions in +conditions+, 
      # such as "group = 'master'". If more than one record is returned from the query, it's the first that'll
      # be used to create the object. In such cases, it might be beneficial to also specify 
      # +orderings+, like "income DESC, name", to control exactly which record is to be used. Example: 
      #   Employee.find_first "income > 50000", "income DESC, name"
      def find_first(conditions = nil, orderings = nil)
        sql  = "SELECT * FROM #{table_name} "
        add_conditions!(sql, conditions)
        sql << "ORDER BY #{orderings} " unless orderings.nil?
        sql << "LIMIT 1"
    
        record = connection.select_one(sql, "#{name} Load First")
        instantiate(record) unless record.nil?
      end
    
      # Creates an object, instantly saves it as a record (if the validation permits it), and returns it. If the save
      # fail under validations, the unsaved object is still returned.
      def create(attributes = nil)
        object = new(attributes)
        object.save
        object
      end
    
      # Updates all records with the SET-part of an SQL update statement in +updates+. A subset of the records can be selected 
      # by specifying +conditions+. Example:
      #   Billing.update_all "category = 'authorized', approved = 1", "author = 'David'"
      def update_all(updates, conditions = nil)
        sql  = "UPDATE #{table_name} SET #{updates} "
        add_conditions!(sql, conditions)
        connection.update(sql, "#{name} Update")
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
        count = connection.select_one(sql, "#{name} Count").values.first
        return count ? count.to_i : 0
      end
        
      # Increments the specified counter by one. So <tt>DiscussionBoard.increment_counter("post_count", 
      # discussion_board_id)</tt> would increment the "post_count" counter on the board responding to discussion_board_id.
      # This is used for caching aggregate values, so that they doesn't need to be computed every time. Especially important
      # for looping over a collection where each element require a number of aggregate values. Like the DiscussionBoard
      # that needs to list both the number of posts and comments.
      def increment_counter(counter_name, id)
        object = find(id)
        object.update_attribute(counter_name, object.send(counter_name) + 1)
      end

      # Works like increment_counter, but decrements instead.
      def decrement_counter(counter_name, id)
        object = find(id)
        object.update_attribute(counter_name, object.send(counter_name) - 1)
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

      # Guesses the table name (in forced lower-case) based on the name of the class in the inheritance hierarchy descending
      # directly from ActiveRecord. So if the hierarchy looks like: Reply < Message < ActiveRecord, then Message is used
      # to guess the table name from even when called on Reply. The guessing rules are as follows:
      # * Class name doesn't end in "s" or "y": An "s" is appended, so a Comment class becomes a comments table. 
      # * Class name ends in a "y": The "y" is replaced with "ies", so a Category class becomes a categories table. 
      # * Class name ends in an "s": No additional characters are added or removed.
      # * Class name with word compositions: Compositions are underscored, so CreditCard class becomes a credit_cards table.
      # Additionally, the class-level table_name_prefix is prepended to the table_name and the table_name_suffix is appended.
      # So if you have "myapp_" as a prefix, the table name guess for an Account class becomes "myapp_accounts".
      #
      # You can also overwrite this class method to allow for unguessable links, such as a Person class with a link to a
      # People table. Example:
      #
      #   class Person < ActiveRecord::Base
      #      def self.table_name() "people" end
      #   end
      def table_name(class_name = class_name_of_active_record_descendant(self))
        table_name_prefix + undecorated_table_name(class_name) + table_name_suffix
      end

      # Defines the primary key field -- can be overridden in subclasses. Overwritting will negate any effect of the
      # primary_key_prefix_type setting, though.
      def primary_key
        case primary_key_prefix_type
          when :table_name                 
            "#{class_name_of_active_record_descendant(self).downcase}id"
          when :table_name_with_underscore
            "#{class_name_of_active_record_descendant(self).downcase}_id"
          else
            "id"
        end
      end

      # Turns the +table_name+ back into a class name following the reverse rules of +table_name+.
      def class_name(table_name) # :nodoc:
        # remove any prefix and/or suffix from the table name
        class_name = table_name[table_name_prefix.length..-(table_name_suffix.length + 1)]

        class_name = class_name.capitalize.gsub(/_(.)/) { |s| $1.capitalize }
      
        if pluralize_table_names
          if class_name[-3,3] == "ies"
            class_name = class_name[0..-4] + "y"
          elsif class_name[-1,1] == "s"
            class_name = class_name[0..-2]
          end
        end

        class_name
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
      # and columns named "type" has been removed.
      def content_columns
        columns.reject { |c| c.name == primary_key || c.name =~ /(_id|_count)$/ || c.name == "type" }
      end

      # Transforms attribute key names into a more humane format, such as "First name" instead of "first_name". Example:
      #   Person.human_attribute_name("first_name") # => "First name"
      def human_attribute_name(attribute_key_name)
        attribute_key_name.gsub(/_/, " ").capitalize unless attribute_key_name.nil?
      end
      
      def descents_from_active_record? # :nodoc:
        superclass == Base
      end

      # Used to sanitize objects before they're used in an SELECT SQL-statement.
      def sanitize(object) # :nodoc:
        return object if Fixnum === object
        object.to_s.gsub(/([;:])/, "").gsub('##', '\#\#').gsub(/'/, "''") # ' (for ruby-mode)
      end

      private
        # Finder methods must instantiate through this method to work with the single-table inheritance model
        # that makes it possible to create objects of different types from the same table.
        def instantiate(record)
          object = record_with_type?(record) ? compute_type(record["type"]).allocate : allocate
          object.instance_variable_set("@attributes", record)
          return object
        end
        
        # Returns true if the +record+ has a type column and is using it.
        def record_with_type?(record)
          record.include?("type") && !record["type"].nil? && !record["type"].empty?
        end
        
        # Returns the name of the type of the record using the current module as a prefix. So descendents of
        # MyApp::Business::Account would be appear as "MyApp::Business::AccountSubclass".
        def type_name_with_module(type_name)
          self.name =~ /::/ ? self.name.scan(/(.*)::/).first.first + "::" + type_name : type_name
        end

        # Adds a sanitized version of +conditions+ to the +sql+ string. Note that it's the passed +sql+ string is changed.
        def add_conditions!(sql, conditions)
          sql << "WHERE #{sanitize_conditions(conditions)} " unless conditions.nil?
          sql << (conditions.nil? ? "WHERE " : " AND ") + "type = '#{name.gsub(/.*::/, '')}' " unless descents_from_active_record?
        end

        # Guesses the table name, but does not decorate it with prefix and suffix information.
        def undecorated_table_name(class_name = class_name_of_active_record_descendant(self))
          table_name = class_name.gsub(/.*::/, '').gsub(/([a-z])([A-Z])/, '\1_\2').downcase

          if pluralize_table_names
            case table_name[-1,1]
              when "s" # no change
              when "y" then table_name = table_name[0..-2] + "ies"
              else table_name = table_name + "s"
            end
          end

          return table_name
        end

      protected        
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

        # Accepts either a condition array or string. The string is returned untouched, but the array has each of
        # the condition values sanitized.
        def sanitize_conditions(conditions)
          if Array === conditions
            statement, values = conditions[0], conditions[1..-1]
            values.collect! { |value| sanitize(value) }
            conditions = statement % values
          end
          
          return conditions
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
        self.attributes = attributes unless attributes.nil?
        yield self if block_given?
      end
      
      # Every Active Record class must use "id" as their primary ID. This getter overwrites the native
      # id method, which isn't being used in this context.
      def id
        read_attribute(self.class.primary_key)
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
            "WHERE #{self.class.primary_key} = '#{id}'", 
            "#{self.class.name} Destroy"
          )
        end

        freeze
      end
      
      # Updates a single attribute and saves the record. This is especially useful for boolean flags on existing records.
      def update_attribute(name, value)
        self.name = value
        save
      end

      # Allows you to set all the attributes at once by passing in a hash with keys
      # matching the attribute names (which again matches the column names). Sensitive attributes can be protected
      # from this form of mass-assignment by using the +attr_protected+ macro. Or you can alternatively
      # specify which attributes *can* be accessed in with the +attr_accessible+ macro. Then all the
      # attributes not included in that won't be allowed to be mass-assigned.
      def attributes=(attributes)
        remove_attributes_protected_from_mass_assignment(attributes)

        multi_parameter_attributes = []
        attributes.each do |k, v| 
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

    private
      def create_or_update
        if new_record? then create else update end
      end

      # Updates the associated record with values matching those of the instant attributes.
      def update
        connection.update(
          "UPDATE #{self.class.table_name} " +
          "SET #{comma_pair_list(attributes_with_quotes)} " +
          "WHERE #{self.class.primary_key} = '#{id}'",
          "#{self.class.name} Update"
        )
      end
      
      # Creates a new record with values matching those of the instant attributes.
      def create
        ensure_proper_type
      
        auto_id = connection.insert(
          "INSERT INTO #{self.class.table_name} " +
          "(#{attributes_with_quotes.keys.join(', ')}) " +
          "VALUES(#{attributes_with_quotes.values.join(', ')})",
          "#{self.class.name} Create"
        )
        
        @new_record = false
        self.id = auto_id if self.id.nil?
      end

      # Sets the type attribute to this class name if this is not the ActiveRecord descendant. Considering the hierarchy
      # Reply < Message < ActiveRecord, this makes it possible to do Reply.new without having to set Reply.type = "Reply"
      # yourself. No type attribute would be set for objects of the Message class in that example.
      def ensure_proper_type
        self.type = self.class.name.gsub(/.*::/, '') unless self.class.descents_from_active_record?
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
        elsif method_name =~ write_method?
          write_attribute($1, arguments[0])
        elsif method_name =~ query_method?
          return query_attribute($1)
        else
          super
        end
      end

      def read_method?()  /^([a-zA-Z][-_\w]*)[^=?]*$/ end
      def write_method?() /^([a-zA-Z][-_\w]*)=.*$/    end
      def query_method?() /^([a-zA-Z][-_\w]*)\?$/     end

      # Returns the value of attribute identified by <tt>attr_name</tt> after it has been type cast (for example, 
      # "2004-12-12" in a data column is cast to a date object, like Date.new(2004, 12, 12)). Can be used when 
      def read_attribute(attr_name) #:doc:
        if column = column_for_attribute(attr_name)
          @attributes[attr_name] = column.type_cast(@attributes[attr_name])
        end
        
        @attributes[attr_name]
      end

      # Updates the attribute identified by <tt>attr_name</tt> with the specified +value+.
      def write_attribute(attr_name, value) #:doc:
        @attributes[attr_name] = value
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
        else
          true
        end
      end

      def remove_attributes_protected_from_mass_assignment(attributes)
        if self.class.accessible_attributes.nil? && self.class.protected_attributes.nil?
          attributes.delete_if { |key, value| key == "id" }
        elsif self.class.protected_attributes.nil?
          attributes.delete_if { |key, value| !self.class.accessible_attributes.include?(key.intern) || key == "id" }
        elsif self.class.accessible_attributes.nil?
          attributes.delete_if { |key, value| self.class.protected_attributes.include?(key.intern) || key == "id" }
        end
      end

      # Returns copy of the attributes hash where all the values have been safely quoted for use in
      # an SQL statement. 
      def attributes_with_quotes
        @attributes.inject({}) { |attrs_quoted, pair| attrs_quoted[pair.first] = quote(pair.last); attrs_quoted }
      end
      
      # Quote strings appropriately for SQL statements.
      def quote(value)
        case value
          when String         then "'#{value.gsub(/\\/,'\&\&').gsub(/'/, "''")}'" # ' (for ruby-mode)
          when NilClass       then "NULL"
          when TrueClass      then "1"
          when FalseClass     then "0"
          when Fixnum, Date   then "'#{value.to_s}'"
          when Time, DateTime then "'#{value.strftime("%Y-%m-%d %H:%M:%S")}'"
          else                     "'#{value.to_yaml}'"
        end
      end

      # Initializes the attributes array with keys matching the columns from the linked table and
      # the values matching the corresponding default value of that column, so
      # that a new instance, or one populated from a passed-in Hash, still has all the attributes
      # that instances loaded from the database would.
      def attributes_from_column_definition
        connection.columns(self.class.table_name, "#{self.class.name} Columns").inject({}) do |attributes, column| 
          attributes[column.name] = column.default unless column.name == "id"
          attributes
        end
      end

      # Instantiates objects for all attribute classes that needs more than one constructor parameter. This is done
      # by calling new on the column type or aggregation type (through composed_of) object with these parameters.
      # So having the pairs written_on(1) = "2004", written_on(2) = "6", written_on(3) = "24", will instantiate
      # written_on (a date type) with Date.new("2004", "6", "24"). You can also specify a typecast character in the
      # parenteses to have the parameters typecasted before they're used in the constructor. Use i for Fixnum, f for Float,
      # s for String, and a for Array.
      def assign_multiparameter_attributes(pairs)
        execute_callstack_for_multiparameter_attributes(
          extract_callstack_for_multiparameter_attributes(pairs)
        )
      end
      
      # Includes an ugly hack for Time.local instead of Time.new because the latter is reserved by Time itself.
      def execute_callstack_for_multiparameter_attributes(callstack)
        callstack.each do |name, values|
          klass = (self.class.reflect_on_aggregation(name) || column_for_attribute(name)).klass
          send(name + "=", Time == klass ? klass.local(*values) : klass.new(*values))
        end
      end
      
      def extract_callstack_for_multiparameter_attributes(pairs)
        attributes = { }

        for pair in pairs
          multiparameter_name, value = pair
          attribute_name = multiparameter_name.split("(").first
          attributes[attribute_name] = [] unless attributes.include?(attribute_name)
          attributes[attribute_name] << 
            [find_parameter_position(multiparameter_name), type_cast_attribute_value(multiparameter_name, value)]
        end
        
        attributes.each { |name, values| attributes[name] = values.sort_by{ |v| v.first }.collect { |v| v.last } }
      end
      
      def type_cast_attribute_value(multiparameter_name, value)
        multiparameter_name =~ /\([0-9]*([a-z])\)/ ? value.send("to_" + $1) : value
      end
      
      def find_parameter_position(multiparameter_name)
        multiparameter_name.scan(/\(([0-9]*).*\)/).first.first
      end
      
      # Returns a comma-seperated pair list, like "key1 = val1, key2 = val2".
      def comma_pair_list(hash)
        hash.inject([]) { |list, pair| list << "#{pair.first} = #{pair.last}" }.join(", ")
      end
  end
end