require 'yaml'
require 'active_record/deprecated_finders'

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
  class ConfigurationError < StandardError #:nodoc:
  end

  class AttributeAssignmentError < ActiveRecordError #:nodoc:
    attr_reader :exception, :attribute
    def initialize(message, exception, attribute)
      @exception = exception
      @attribute = attribute
      @message = message
    end
  end

  class MultiparameterAssignmentErrors < ActiveRecordError #:nodoc:
    attr_reader :errors
    def initialize(errors)
      @errors = errors
    end
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
  #   user = User.new(:name => "David", :occupation => "Code Artist")
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
  #       find(:first, :conditions => "user_name = '#{user_name}' AND password = '#{password}'")
  #     end
  #
  #     def self.authenticate_safely(user_name, password)
  #       find(:first, :conditions => [ "user_name = ? AND password = ?", user_name, password ])
  #     end
  #   end
  #
  # The <tt>authenticate_unsafely</tt> method inserts the parameters directly into the query and is thus susceptible to SQL-injection
  # attacks if the <tt>user_name</tt> and +password+ parameters come directly from a HTTP request. The <tt>authenticate_safely</tt> method,
  # on the other hand, will sanitize the <tt>user_name</tt> and +password+ before inserting them in the query, which will ensure that
  # an attacker can't escape the query and fake the login (or worse).
  #
  # When using multiple parameters in the conditions, it can easily become hard to read exactly what the fourth or fifth
  # question mark is supposed to represent. In those cases, you can resort to named bind variables instead. That's done by replacing
  # the question marks with symbols and supplying a hash with values for the matching symbol keys:
  #
  #   Company.find(:first, [
  #     "id = :id AND name = :name AND division = :division AND created_at > :accounting_date",
  #     { :id => 3, :name => "37signals", :division => "First", :accounting_date => '2005-01-01' }
  #   ])
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
  #       write_attribute(:length, minutes * 60)
  #     end
  #
  #     def length
  #       read_attribute(:length) / 60
  #     end
  #   end
  #
  # You can alternatively use self[:attribute]=(value) and self[:attribute] instead of write_attribute(:attribute, vaule) and
  # read_attribute(:attribute) as a shorter form.
  #
  # == Accessing attributes before they have been type casted
  #
  # Some times you want to be able to read the raw attribute data without having the column-determined type cast run its course first.
  # That can be done by using the <attribute>_before_type_cast accessors that all attributes have. For example, if your Account model
  # has a balance attribute, you can call account.balance_before_type_cast or account.id_before_type_cast.
  #
  # This is especially useful in validation situations where the user might supply a string for an integer field and you want to display
  # the original string back in an error message. Accessing the attribute normally would type cast the string to 0, which isn't what you
  # want.
  #
  # == Dynamic attribute-based finders
  #
  # Dynamic attribute-based finders are a cleaner way of getting objects by simple queries without turning to SQL. They work by
  # appending the name of an attribute to <tt>find_by_</tt> or <tt>find_all_by_</tt>, so you get finders like Person.find_by_user_name,
  # Person.find_all_by_last_name, Payment.find_by_transaction_id. So instead of writing
  # <tt>Person.find(:first, ["user_name = ?", user_name])</tt>, you just do <tt>Person.find_by_user_name(user_name)</tt>.
  # And instead of writing <tt>Person.find(:all, ["last_name = ?", last_name])</tt>, you just do <tt>Person.find_all_by_last_name(last_name)</tt>.
  #
  # It's also possible to use multiple attributes in the same find by separating them with "_and_", so you get finders like
  # <tt>Person.find_by_user_name_and_password</tt> or even <tt>Payment.find_by_purchaser_and_state_and_country</tt>. So instead of writing
  # <tt>Person.find(:first, ["user_name = ? AND password = ?", user_name, password])</tt>, you just do
  # <tt>Person.find_by_user_name_and_password(user_name, password)</tt>.
  #
  # It's even possible to use all the additional parameters to find. For example, the full interface for Payment.find_all_by_amount
  # is actually Payment.find_all_by_amount(amount, options). And the full interface to Person.find_by_user_name is
  # actually Person.find_by_user_name(user_name, options). So you could call <tt>Payment.find_all_by_amount(50, :order => "created_on")</tt>.
  #
  # == Saving arrays, hashes, and other non-mappable objects in text columns
  #
  # Active Record can serialize any object in text columns using YAML. To do so, you must specify this with a call to the class method +serialize+.
  # This makes it possible to store arrays, hashes, and other non-mappeable objects without doing any additional work. Example:
  #
  #   class User < ActiveRecord::Base
  #     serialize :preferences
  #   end
  #
  #   user = User.create(:preferences) => { "background" => "black", "display" => large })
  #   User.find(user.id).preferences # => { "background" => "black", "display" => large }
  #
  # You can also specify an class option as the second parameter that'll raise an exception if a serialized object is retrieved as a
  # descendent of a class not in the hierarchy. Example:
  #
  #   class User < ActiveRecord::Base
  #     serialize :preferences, Hash
  #   end
  #
  #   user = User.create(:preferences => %w( one two three ))
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
  # When you do Firm.create(:name => "37signals"), this record will be saved in the companies table with type = "Firm". You can then
  # fetch this row again using Company.find(:first, "name = '37signals'") and it will return a Firm object.
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
  # * +AdapterNotSpecified+ -- the <tt>:adapter</tt> key used in <tt>establish_connection</tt> specified an non-existent adapter
  #   (or a bad spelling of an existing one).
  # * +AssociationTypeMismatch+ -- the object assigned to the association wasn't of the type specified in the association definition.
  # * +SerializationTypeMismatch+ -- the object serialized wasn't of the class specified as the second parameter.
  # * +ConnectionNotEstablished+ -- no connection has been established. Use <tt>establish_connection</tt> before querying.
  # * +RecordNotFound+ -- no record responded to the find* method.
  #   Either the row with the given ID doesn't exist or the row didn't meet the additional restrictions.
  # * +StatementInvalid+ -- the database server rejected the SQL statement. The precise error is added in the  message.
  #   Either the record with the given ID doesn't exist or the record didn't meet the additional restrictions.
  # * +MultiparameterAssignmentErrors+ -- collection of errors that occurred during a mass assignment using the
  #   +attributes=+ method. The +errors+ property of this exception contains an array of +AttributeAssignmentError+
  #   objects that should be inspected to determine which attributes triggered the errors.
  # * +AttributeAssignmentError+ -- an error occurred while doing a mass assignment through the +attributes=+ method.
  #   You can inspect the +attribute+ property of the exception object to determine which attribute triggered the error.
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
    @@configurations = {}

    # Accessor for the prefix type that will be prepended to every primary key column name. The options are :table_name and
    # :table_name_with_underscore. If the first is specified, the Product class will look for "productid" instead of "id" as
    # the primary column. If the latter is specified, the Product class will look for "product_id" instead of "id". Remember
    # that this is a global setting for all Active Records.
    cattr_accessor :primary_key_prefix_type
    @@primary_key_prefix_type = nil

    # Accessor for the name of the prefix string to prepend to every table name. So if set to "basecamp_", all
    # table names will be named like "basecamp_projects", "basecamp_people", etc. This is a convenient way of creating a namespace
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

    # Determines whether or not to use ANSI codes to colorize the logging statements committed by the connection adapter. These colors
    # makes it much easier to overview things during debugging (when used through a reader like +tail+ and on a black background), but
    # may complicate matters if you use software like syslog. This is true, by default.
    cattr_accessor :colorize_logging
    @@colorize_logging = true

    # Determines whether to use Time.local (using :local) or Time.utc (using :utc) when pulling dates and times from the database.
    # This is set to :local by default.
    cattr_accessor :default_timezone
    @@default_timezone = :local
    
    # Determines whether or not to use a connection for each thread, or a single shared connection for all threads.
    # Defaults to true; Railties' WEBrick server sets this to false.
    cattr_accessor :threaded_connections
    @@threaded_connections = true

    class << self # Class methods
      # Find operates with three different retreval approaches:
      #
      # * Find by id: This can either be a specific id (1), a list of ids (1, 5, 6), or an array of ids ([5, 6, 10]).
      #   If no record can be found for all of the listed ids, then RecordNotFound will be raised.
      # * Find first: This will return the first record matched by the options used. These options can either be specific
      #   conditions or merely an order. If no record can matched, nil is returned.
      # * Find all: This will return all the records matched by the options used. If no records are found, an empty array is returned.
      #
      # All approaches accepts an option hash as their last parameter. The options are:
      #
      # * <tt>:conditions</tt>: An SQL fragment like "administrator = 1" or [ "user_name = ?", username ]. See conditions in the intro.
      # * <tt>:order</tt>: An SQL fragment like "created_at DESC, name".
      # * <tt>:limit</tt>: An integer determining the limit on the number of rows that should be returned.
      # * <tt>:offset</tt>: An integer determining the offset from where the rows should be fetched. So at 5, it would skip the first 4 rows.
      # * <tt>:joins</tt>: An SQL fragment for additional joins like "LEFT JOIN comments ON comments.post_id = id". (Rarely needed).
      # * <tt>:include</tt>: Names associations that should be loaded alongside using LEFT OUTER JOINs. The symbols named refer
      #   to already defined associations. See eager loading under Associations.
      #
      # Examples for find by id:
      #   Person.find(1)       # returns the object for ID = 1
      #   Person.find(1, 2, 6) # returns an array for objects with IDs in (1, 2, 6)
      #   Person.find([7, 17]) # returns an array for objects with IDs in (7, 17)
      #   Person.find([1])     # returns an array for objects the object with ID = 1
      #   Person.find(1, :conditions => "administrator = 1", :order => "created_on DESC")
      #
      # Examples for find first:
      #   Person.find(:first) # returns the first object fetched by SELECT * FROM people
      #   Person.find(:first, :conditions => [ "user_name = ?", user_name])
      #   Person.find(:first, :order => "created_on DESC", :offset => 5)
      #
      # Examples for find all:
      #   Person.find(:all) # returns an array of objects for all the rows fetched by SELECT * FROM people
      #   Person.find(:all, :conditions => [ "category IN (?)", categories], :limit => 50)
      #   Person.find(:all, :offset => 10, :limit => 10)
      #   Person.find(:all, :include => [ :account, :friends ])
      def find(*args)
        options = extract_options_from_args!(args)

        case args.first
          when :first
            find(:all, options.merge(options[:include] ? { } : { :limit => 1 })).first
          when :all
            options[:include] ? find_with_associations(options) : find_by_sql(construct_finder_sql(options))
          else
            return args.first if args.first.kind_of?(Array) && args.first.empty?
            expects_array = args.first.kind_of?(Array)
            conditions = " AND #{sanitize_sql(options[:conditions])}" if options[:conditions]

            ids = args.flatten.compact.uniq
            case ids.size
              when 0
                raise RecordNotFound, "Couldn't find #{name} without an ID#{conditions}"
              when 1
                if result = find(:first, options.merge({ :conditions => "#{table_name}.#{primary_key} = #{sanitize(ids.first)}#{conditions}" }))
                  return expects_array ? [ result ] : result
                else
                  raise RecordNotFound, "Couldn't find #{name} with ID=#{ids.first}#{conditions}"
                end
              else
                # Find multiple ids
                ids_list = ids.map { |id| sanitize(id) }.join(',')
                result   = find(:all, options.merge({ :conditions => "#{table_name}.#{primary_key} IN (#{ids_list})#{conditions}"}))
                if result.size == ids.size
                  return result
                else
                  raise RecordNotFound, "Couldn't find all #{name.pluralize} with IDs (#{ids_list})#{conditions}"
                end
            end
        end
      end

      # Works like find(:all), but requires a complete SQL string. Examples:
      #   Post.find_by_sql "SELECT p.*, c.author FROM posts p, comments c WHERE p.id = c.post_id"
      #   Post.find_by_sql ["SELECT * FROM posts WHERE author = ? AND created > ?", author_id, start_date]
      def find_by_sql(sql)
        connection.select_all(sanitize_sql(sql), "#{name} Load").collect! { |record| instantiate(record) }
      end

      # Returns true if the given +id+ represents the primary key of a record in the database, false otherwise.
      # Example:
      #   Person.exists?(5)
      def exists?(id)
        !find(:first, :conditions => ["#{primary_key} = ?", id]).nil? rescue false
      end

      # Creates an object, instantly saves it as a record (if the validation permits it), and returns it. If the save
      # fail under validations, the unsaved object is still returned.
      def create(attributes = nil)
        if attributes.is_a?(Array)
          attributes.collect { |attr| create(attr) }
        else
          object = new(attributes)
          object.save
          object
        end
      end

      # Finds the record from the passed +id+, instantly saves it with the passed +attributes+ (if the validation permits it),
      # and returns it. If the save fail under validations, the unsaved object is still returned.
      def update(id, attributes)
        if id.is_a?(Array)
          idx = -1
          id.collect { |id| idx += 1; update(id, attributes[idx]) }
        else
          object = find(id)
          object.update_attributes(attributes)
          object
        end
      end

      # Deletes the record with the given +id+ without instantiating an object first. If an array of ids is provided, all of them
      # are deleted.
      def delete(id)
        delete_all([ "#{primary_key} IN (?)", id ])
      end

      # Destroys the record with the given +id+ by instantiating the object and calling #destroy (all the callbacks are the triggered).
      # If an array of ids is provided, all of them are destroyed.
      def destroy(id)
        id.is_a?(Array) ? id.each { |id| destroy(id) } : find(id).destroy
      end

      # Updates all records with the SET-part of an SQL update statement in +updates+ and returns an integer with the number of rows updates.
      # A subset of the records can be selected by specifying +conditions+. Example:
      #   Billing.update_all "category = 'authorized', approved = 1", "author = 'David'"
      def update_all(updates, conditions = nil)
        sql  = "UPDATE #{table_name} SET #{sanitize_sql(updates)} "
        add_conditions!(sql, conditions)
        connection.update(sql, "#{name} Update")
      end

      # Destroys the objects for all the records that matches the +condition+ by instantiating each object and calling
      # the destroy method. Example:
      #   Person.destroy_all "last_login < '2004-04-04'"
      def destroy_all(conditions = nil)
        find(:all, :conditions => conditions).each { |object| object.destroy }
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
      def count(conditions = nil, joins = nil)
        sql  = "SELECT COUNT(*) FROM #{table_name} "
        sql << " #{joins} " if joins
        add_conditions!(sql, conditions)
        count_by_sql(sql)
      end

      # Returns the result of an SQL statement that should only include a COUNT(*) in the SELECT part.
      #   Product.count "SELECT COUNT(*) FROM sales s, customers c WHERE s.customer_id = c.id"
      def count_by_sql(sql)
        sql = sanitize_conditions(sql)
        rows = connection.select_one(sql, "#{name} Count")

        if !rows.nil? and count = rows.values.first
          count.to_i
        else
          0
        end
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

      # Returns an array of all the attributes that have been protected from mass-assignment.
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

      # Returns an array of all the attributes that have been made accessible to mass-assignment.
      def accessible_attributes # :nodoc:
        read_inheritable_attribute("attr_accessible")
      end

      # Specifies that the attribute by the name of +attr_name+ should be serialized before saving to the database and unserialized
      # after loading from the database. The serialization is done through YAML. If +class_name+ is specified, the serialized
      # object must be of that class on retrieval or +SerializationTypeMismatch+ will be raised.
      def serialize(attr_name, class_name = Object)
        serialized_attributes[attr_name.to_s] = class_name
      end

      # Returns a hash of all the attributes that have been specified for serialization as keys and their class restriction as values.
      def serialized_attributes
        read_inheritable_attribute("attr_serialized") or write_inheritable_attribute("attr_serialized", {})
      end

      # Guesses the table name (in forced lower-case) based on the name of the class in the inheritance hierarchy descending
      # directly from ActiveRecord. So if the hierarchy looks like: Reply < Message < ActiveRecord, then Message is used
      # to guess the table name from even when called on Reply. The rules used to do the guess are handled by the Inflector class
      # in Active Support, which knows almost all common English inflections (report a bug if your inflection isn't covered).
      #
      # Additionally, the class-level table_name_prefix is prepended to the table_name and the table_name_suffix is appended.
      # So if you have "myapp_" as a prefix, the table name guess for an Account class becomes "myapp_accounts".
      #
      # You can also overwrite this class method to allow for unguessable links, such as a Mouse class with a link to a
      # "mice" table. Example:
      #
      #   class Mouse < ActiveRecord::Base
      #      set_table_name "mice"
      #   end
      def table_name
        "#{table_name_prefix}#{undecorated_table_name(class_name_of_active_record_descendant(self))}#{table_name_suffix}"
      end

      # Defines the primary key field -- can be overridden in subclasses. Overwriting will negate any effect of the
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

      # Sets the table name to use to the given value, or (if the value
      # is nil or false) to the value returned by the given block.
      #
      # Example:
      #
      #   class Project < ActiveRecord::Base
      #     set_table_name "project"
      #   end
      def set_table_name( value=nil, &block )
        define_attr_method :table_name, value, &block
      end
      alias :table_name= :set_table_name

      # Sets the name of the primary key column to use to the given value,
      # or (if the value is nil or false) to the value returned by the given
      # block.
      #
      # Example:
      #
      #   class Project < ActiveRecord::Base
      #     set_primary_key "sysid"
      #   end
      def set_primary_key( value=nil, &block )
        define_attr_method :primary_key, value, &block
      end
      alias :primary_key= :set_primary_key

      # Sets the name of the inheritance column to use to the given value,
      # or (if the value # is nil or false) to the value returned by the
      # given block.
      #
      # Example:
      #
      #   class Project < ActiveRecord::Base
      #     set_inheritance_column do
      #       original_inheritance_column + "_id"
      #     end
      #   end
      def set_inheritance_column( value=nil, &block )
        define_attr_method :inheritance_column, value, &block
      end
      alias :inheritance_column= :set_inheritance_column

      # Turns the +table_name+ back into a class name following the reverse rules of +table_name+.
      def class_name(table_name = table_name) # :nodoc:
        # remove any prefix and/or suffix from the table name
        class_name = table_name[table_name_prefix.length..-(table_name_suffix.length + 1)].camelize
        class_name = class_name.singularize if pluralize_table_names
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

      def column_names
        @column_names ||= columns.map { |column| column.name }
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
        @dynamic_methods_hash ||= column_names.inject(Hash.new(false)) do |methods, attr|
          methods[attr.to_sym]       = true
          methods["#{attr}=".to_sym] = true
          methods["#{attr}?".to_sym] = true
          methods["#{attr}_before_type_cast".to_sym] = true
          methods
        end
      end

      # Resets all the cached information about columns, which will cause they to be reloaded on the next request.
      def reset_column_information
        @column_names = @columns = @columns_hash = @content_columns = @dynamic_methods_hash = nil
      end

      def reset_column_information_and_inheritable_attributes_for_all_subclasses#:nodoc:
        subclasses.each { |klass| klass.reset_inheritable_attributes; klass.reset_column_information }
      end

      # Transforms attribute key names into a more humane format, such as "First name" instead of "first_name". Example:
      #   Person.human_attribute_name("first_name") # => "First name"
      # Deprecated in favor of just calling "first_name".humanize
      def human_attribute_name(attribute_key_name) #:nodoc:
        attribute_key_name.humanize
      end

      def descends_from_active_record? # :nodoc:
        superclass == Base || !columns_hash.include?(inheritance_column)
      end

      def quote(object) #:nodoc:
        connection.quote(object)
      end

      # Used to sanitize objects before they're used in an SELECT SQL-statement. Delegates to <tt>connection.quote</tt>.
      def sanitize(object) #:nodoc:
        connection.quote(object)
      end

      # Log and benchmark multiple statements in a single block.
      # Usage (hides all the SQL calls for the individual actions and calculates total runtime for them all):
      #
      #   Project.benchmark("Creating project") do
      #     project = Project.create("name" => "stuff")
      #     project.create_manager("name" => "David")
      #     project.milestones << Milestone.find(:all)
      #   end
      def benchmark(title)
        result = nil
        seconds = Benchmark.realtime { result = silence { yield } }
        logger.info "#{title} (#{sprintf("%f", seconds)})" if logger
        return result
      end

      # Silences the logger for the duration of the block.
      def silence
        old_logger_level, logger.level = logger.level, Logger::ERROR if logger
        yield
      ensure
        logger.level = old_logger_level if logger
      end

      # Overwrite the default class equality method to provide support for association proxies.
      def ===(object)
        object.is_a?(self)
      end

      private
        # Finder methods must instantiate through this method to work with the single-table inheritance model
        # that makes it possible to create objects of different types from the same table.
        def instantiate(record)
          subclass_name = record[inheritance_column]
          require_association_class(subclass_name)

          object = if subclass_name.blank?
            allocate
          else
            begin
              compute_type(subclass_name).allocate
            rescue NameError
              raise SubclassNotFound,
                "The single-table inheritance mechanism failed to locate the subclass: '#{record[inheritance_column]}'. " +
                "This error is raised because the column '#{inheritance_column}' is reserved for storing the class in case of inheritance. " +
                "Please rename this column if you didn't intend it to be used for storing the inheritance class " +
                "or overwrite #{self.to_s}.inheritance_column to use another column for that information."
            end
          end

          object.instance_variable_set("@attributes", record)
          object
        end

        # Returns the name of the type of the record using the current module as a prefix. So descendents of
        # MyApp::Business::Account would be appear as "MyApp::Business::AccountSubclass".
        def type_name_with_module(type_name)
          self.name =~ /::/ ? self.name.scan(/(.*)::/).first.first + "::" + type_name : type_name
        end

        def construct_finder_sql(options)
          sql  = "SELECT * FROM #{table_name} "
          sql << " #{options[:joins]} " if options[:joins]
          add_conditions!(sql, options[:conditions])
          sql << "ORDER BY #{options[:order]} " if options[:order]
          add_limit!(sql, options)
          sql
        end

        def add_limit!(sql, options)
          connection.add_limit_offset!(sql, options)
        end

        # Adds a sanitized version of +conditions+ to the +sql+ string. Note that it's the passed +sql+ string is changed.
        def add_conditions!(sql, conditions)
          sql << "WHERE #{sanitize_sql(conditions)} " unless conditions.nil?
          sql << (conditions.nil? ? "WHERE " : " AND ") + type_condition unless descends_from_active_record?
        end

        def type_condition
          type_condition = subclasses.inject("#{table_name}.#{inheritance_column} = '#{name.demodulize}' ") do |condition, subclass|
            condition << "OR #{table_name}.#{inheritance_column} = '#{subclass.name.demodulize}' "
          end

          " (#{type_condition}) "
        end

        # Guesses the table name, but does not decorate it with prefix and suffix information.
        def undecorated_table_name(class_name = class_name_of_active_record_descendant(self))
          table_name = Inflector.underscore(Inflector.demodulize(class_name))
          table_name = Inflector.pluralize(table_name) if pluralize_table_names
          table_name
        end

        # Enables dynamic finders like find_by_user_name(user_name) and find_by_user_name_and_password(user_name, password) that are turned into
        # find(:first, :conditions => ["user_name = ?", user_name]) and  find(:first, :conditions => ["user_name = ? AND password = ?", user_name, password])
        # respectively. Also works for find(:all), but using find_all_by_amount(50) that are turned into find(:all, :conditions => ["amount = ?", 50]).
        #
        # It's even possible to use all the additional parameters to find. For example, the full interface for find_all_by_amount
        # is actually find_all_by_amount(amount, options).
        def method_missing(method_id, *arguments)
          method_name = method_id.id2name

          if md = /find_(all_by|by)_([_a-zA-Z]\w*)/.match(method_id.to_s)
            finder = md.captures.first == 'all_by' ? :all : :first
            attributes = md.captures.last.split('_and_')
            attributes.each { |attr_name| super unless column_methods_hash.include?(attr_name.to_sym) }

            attr_index = -1
            conditions = attributes.collect { |attr_name| attr_index += 1; "#{attr_name} #{attribute_condition(arguments[attr_index])} " }.join(" AND ")

            if arguments[attributes.length].is_a?(Hash)
              find(finder, { :conditions => [conditions, *arguments[0...attributes.length]] }.update(arguments[attributes.length]))
            else
              # deprecated API
              send("find_#{finder}", [conditions, *arguments[0...attributes.length]], *arguments[attributes.length..-1])
            end
          else
            super
          end
        end

        def attribute_condition(argument)
          case argument
            when nil   then "IS ?"
            when Array then "IN (?)"
            else            "= ?"
          end
        end

        # Defines an "attribute" method (like #inheritance_column or
        # #table_name). A new (class) method will be created with the
        # given name. If a value is specified, the new method will
        # return that value (as a string). Otherwise, the given block
        # will be used to compute the value of the method.
        #
        # The original method will be aliased, with the new name being
        # prefixed with "original_". This allows the new method to
        # access the original value.
        #
        # Example:
        #
        #   class A < ActiveRecord::Base
        #     define_attr_method :primary_key, "sysid"
        #     define_attr_method( :inheritance_column ) do
        #       original_inheritance_column + "_id"
        #     end
        #   end
        def define_attr_method(name, value=nil, &block)
          sing = class << self; self; end
          block = proc { value.to_s } if value
          sing.send( :alias_method, "original_#{name}", name )
          sing.send( :define_method, name, &block )
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
            final_type.const_get(part)
          end
        end

        # Returns the name of the class descending directly from ActiveRecord in the inheritance hierarchy.
        def class_name_of_active_record_descendant(klass)
          if klass.superclass == Base
            klass.name
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
          statement.gsub('?') { quote_bound_value(bound.shift) }
        end

        def replace_named_bind_variables(statement, bind_vars)
          raise_if_bind_arity_mismatch(statement, statement.scan(/:(\w+)/).uniq.size, bind_vars.size)
          statement.gsub(/:(\w+)/) do
            match = $1.to_sym
            if bind_vars.include?(match)
              quote_bound_value(bind_vars[match])
            else
              raise PreparedStatementInvalid, "missing value for :#{match} in #{statement}"
            end
          end
        end

        def quote_bound_value(value)
          if (value.respond_to?(:map) && !value.is_a?(String))
            value.map { |v| connection.quote(v) }.join(',')
          else
            connection.quote(value)
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

      # Enables Active Record objects to be used as URL parameters in Action Pack automatically.
      alias_method :to_param, :id

      def id_before_type_cast #:nodoc:
        read_attribute_before_type_cast(self.class.primary_key)
      end

      def quoted_id #:nodoc:
        quote(id, column_for_attribute(self.class.primary_key))
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
      end

      # Deletes the record in the database and freezes this instance to reflect that no changes should
      # be made (since they can't be persisted).
      def destroy
        unless new_record?
          connection.delete <<-end_sql, "#{self.class.name} Destroy"
            DELETE FROM #{self.class.table_name}
            WHERE #{self.class.primary_key} = #{quoted_id}
          end_sql
        end

        freeze
      end

      # Returns a clone of the record that hasn't been assigned an id yet and is treated as a new record.
      def clone
        attrs = self.attributes_before_type_cast
        attrs.delete(self.class.primary_key)
        self.class.new do |record|
          record.send :instance_variable_set, '@attributes', attrs
        end
      end

      # Updates a single attribute and saves the record. This is especially useful for boolean flags on existing records.
      # Note: This method is overwritten by the Validation module that'll make sure that updates made with this method
      # doesn't get subjected to validation checks. Hence, attributes can be updated even if the full object isn't valid.
      def update_attribute(name, value)
        self[name] = value
        save
      end

      # Updates all the attributes in from the passed hash and saves the record. If the object is invalid, the saving will
      # fail and false will be returned.
      def update_attributes(attributes)
        self.attributes = attributes
        save
      end

      # Initializes the +attribute+ to zero if nil and adds one. Only makes sense for number-based attributes. Returns self.
      def increment(attribute)
        self[attribute] ||= 0
        self[attribute] += 1
        self
      end

      # Increments the +attribute+ and saves the record.
      def increment!(attribute)
        increment(attribute).update_attribute(attribute, self[attribute])
      end

      # Initializes the +attribute+ to zero if nil and subtracts one. Only makes sense for number-based attributes. Returns self.
      def decrement(attribute)
        self[attribute] ||= 0
        self[attribute] -= 1
        self
      end

      # Decrements the +attribute+ and saves the record.
      def decrement!(attribute)
        decrement(attribute).update_attribute(attribute, self[attribute])
      end

      # Turns an +attribute+ that's currently true into false and vice versa. Returns self.
      def toggle(attribute)
        self[attribute] = quote(!send("#{attribute}?", column_for_attribute(attribute)))
        self
      end

      # Toggles the +attribute+ and saves the record.
      def toggle!(attribute)
        toggle(attribute).update_attribute(attribute, self[attribute])
      end

      # Reloads the attributes of this object from the database.
      def reload
        clear_association_cache
        @attributes.update(self.class.find(self.id).instance_variable_get('@attributes'))
        self
      end

      # Returns the value of attribute identified by <tt>attr_name</tt> after it has been type cast (for example,
      # "2004-12-12" in a data column is cast to a date object, like Date.new(2004, 12, 12)).
      # (Alias for the protected read_attribute method).
      def [](attr_name)
        read_attribute(attr_name.to_s)
      end

      # Updates the attribute identified by <tt>attr_name</tt> with the specified +value+.
      # (Alias for the protected write_attribute method).
      def []=(attr_name, value)
        write_attribute(attr_name.to_s, value)
      end

      # Allows you to set all the attributes at once by passing in a hash with keys
      # matching the attribute names (which again matches the column names). Sensitive attributes can be protected
      # from this form of mass-assignment by using the +attr_protected+ macro. Or you can alternatively
      # specify which attributes *can* be accessed in with the +attr_accessible+ macro. Then all the
      # attributes not included in that won't be allowed to be mass-assigned.
      def attributes=(attributes)
        return if attributes.nil?
        attributes.stringify_keys!

        multi_parameter_attributes = []
        remove_attributes_protected_from_mass_assignment(attributes).each do |k, v|
          k.include?("(") ? multi_parameter_attributes << [ k, v ] : send(k + "=", v)
        end
        assign_multiparameter_attributes(multi_parameter_attributes)
      end

      # Returns a hash of all the attributes with their names as keys and clones of their objects as values.
      def attributes
        clone_attributes :read_attribute
      end

      # Returns a hash of cloned attributes before typecasting and deserialization.
      def attributes_before_type_cast
        clone_attributes :read_attribute_before_type_cast
      end

      # Returns true if the specified +attribute+ has been set by the user or by a database load and is neither
      # nil nor empty? (the latter only applies to objects that responds to empty?, most notably Strings).
      def attribute_present?(attribute)
        value = read_attribute(attribute)
        !value.blank? or value == 0
      end

      # Returns an array of names for the attributes available on this object sorted alphabetically.
      def attribute_names
        @attributes.keys.sort
      end

      # Returns the column object for the named attribute.
      def column_for_attribute(name)
        self.class.columns_hash[name.to_s]
      end

      # Returns true if the +comparison_object+ is the same object, or is of the same type and has the same id.
      def ==(comparison_object)
        comparison_object.equal?(self) or (comparison_object.instance_of?(self.class) and comparison_object.id == id)
      end

      # Delegates to ==
      def eql?(comparison_object)
        self == (comparison_object)
      end

      # Delegates to id in order to allow two records of the same type and id to work with something like:
      #   [ Person.find(1), Person.find(2), Person.find(3) ] & [ Person.find(1), Person.find(4) ] # => [ Person.find(1) ]
      def hash
        id.hash
      end

      # For checking respond_to? without searching the attributes (which is faster).
      alias_method :respond_to_without_attributes?, :respond_to?

      # A Person object with a name attribute can ask person.respond_to?("name"), person.respond_to?("name="), and
      # person.respond_to?("name?") which will all return true.
      def respond_to?(method, include_priv = false)
        self.class.column_methods_hash[method.to_sym] || respond_to_without_attributes?(method, include_priv)
      end

      # Just freeze the attributes hash, such that associations are still accessible even on destroyed records.
      def freeze
        @attributes.freeze
      end

      def frozen?
        @attributes.frozen?
      end

    private
      def create_or_update
        if new_record? then create else update end
        true
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
      def method_missing(method_id, *args, &block)
        method_name = method_id.to_s
        if @attributes.include?(method_name)
          read_attribute(method_name)
        elsif md = /(=|\?|_before_type_cast)$/.match(method_name)
          attribute_name, method_type = md.pre_match, md.to_s
          if @attributes.include?(attribute_name)
            case method_type
              when '='
                write_attribute(attribute_name, args.first)
              when '?'
                query_attribute(attribute_name)
              when '_before_type_cast'
                read_attribute_before_type_cast(attribute_name)
            end
          else
            super
          end
        else
          super
        end
      end

      # Returns the value of attribute identified by <tt>attr_name</tt> after it has been type cast (for example,
      # "2004-12-12" in a data column is cast to a date object, like Date.new(2004, 12, 12)).
      def read_attribute(attr_name)
        if !(value = @attributes[attr_name]).nil?
          if column = column_for_attribute(attr_name)
            if unserializable_attribute?(attr_name, column)
              unserialize_attribute(attr_name)
            else
              column.type_cast(value)
            end
          else
            value
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
        if value = @attributes[attr_name]
          [:text, :string].include?(column.send(:type)) && value.is_a?(String) && self.class.serialized_attributes[attr_name]
        end
      end

      # Returns the unserialized object of the attribute.
      def unserialize_attribute(attr_name)
        unserialized_object = object_from_yaml(@attributes[attr_name])

        if unserialized_object.is_a?(self.class.serialized_attributes[attr_name])
          @attributes[attr_name] = unserialized_object
        else
          raise SerializationTypeMismatch,
            "#{attr_name} was supposed to be a #{self.class.serialized_attributes[attr_name]}, but was a #{unserialized_object.class.to_s}"
        end
      end

      # Updates the attribute identified by <tt>attr_name</tt> with the specified +value+. Empty strings for fixnum and float
      # columns are turned into nil.
      def write_attribute(attr_name, value)
        @attributes[attr_name.to_s] = empty_string_for_number_column?(attr_name.to_s, value) ? nil : value
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
          attributes.reject { |key, value| attributes_protected_by_default.include?(key.gsub(/\(.+/, "")) }
        elsif self.class.protected_attributes.nil?
          attributes.reject { |key, value| !self.class.accessible_attributes.include?(key.gsub(/\(.+/, "").intern) || attributes_protected_by_default.include?(key.gsub(/\(.+/, "")) }
        elsif self.class.accessible_attributes.nil?
          attributes.reject { |key, value| self.class.protected_attributes.include?(key.gsub(/\(.+/,"").intern) || attributes_protected_by_default.include?(key.gsub(/\(.+/, "")) }
        end
      end

      # The primary key and inheritance column can never be set by mass-assignment for security reasons.
      def attributes_protected_by_default
        [ self.class.primary_key, self.class.inheritance_column ]
      end

      # Returns copy of the attributes hash where all the values have been safely quoted for use in
      # an SQL statement.
      def attributes_with_quotes(include_primary_key = true)
        attributes.inject({}) do |quoted, (name, value)|
          if column = column_for_attribute(name)
            quoted[name] = quote(value, column) unless !include_primary_key && name == self.class.primary_key
          end
          quoted
        end
      end

      # Quote strings appropriately for SQL statements.
      def quote(value, column = nil)
        self.class.connection.quote(value, column)
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
      # parentheses to have the parameters typecasted before they're used in the constructor. Use i for Fixnum, f for Float,
      # s for String, and a for Array. If all the values for a given attribute is empty, the attribute will be set to nil.
      def assign_multiparameter_attributes(pairs)
        execute_callstack_for_multiparameter_attributes(
          extract_callstack_for_multiparameter_attributes(pairs)
        )
      end

      # Includes an ugly hack for Time.local instead of Time.new because the latter is reserved by Time itself.
      def execute_callstack_for_multiparameter_attributes(callstack)
        errors = []
        callstack.each do |name, values|
          klass = (self.class.reflect_on_aggregation(name) || column_for_attribute(name)).klass
          if values.empty?
            send(name + "=", nil)
          else
            begin
              send(name + "=", Time == klass ? klass.local(*values) : klass.new(*values))
            rescue => ex
              errors << AttributeAssignmentError.new("error on assignment #{values.inspect} to #{name}", ex, name)
            end
          end
        end
        unless errors.empty?
          raise MultiparameterAssignmentErrors.new(errors), "#{errors.size} error(s) on assignment of multiparameter attributes"
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
              [ find_parameter_position(multiparameter_name), type_cast_attribute_value(multiparameter_name, value) ]
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
        attributes.keys.collect do |column_name|
          self.class.connection.quote_column_name(column_name)
        end
      end

      def quote_columns(quoter, hash)
        hash.inject({}) do |quoted, (name, value)|
          quoted[quoter.quote_column_name(name)] = value
          quoted
        end
      end

      def quoted_comma_pair_list(quoter, hash)
        comma_pair_list(quote_columns(quoter, hash))
      end

      def object_from_yaml(string)
        return string unless string.is_a?(String)
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

      def clone_attributes(reader_method = :read_attribute, attributes = {})
        self.attribute_names.inject(attributes) do |attributes, name|
          attributes[name] = clone_attribute_value(reader_method, name)
          attributes
        end
      end

      def clone_attribute_value(reader_method, attribute_name)
        value = send(reader_method, attribute_name)
        value.clone
      rescue TypeError, NoMethodError
        value
      end
  end
end
