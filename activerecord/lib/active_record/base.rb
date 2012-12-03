begin
  require 'psych'
rescue LoadError
end

require 'yaml'
require 'set'
require 'thread'
require 'active_support/benchmarkable'
require 'active_support/dependencies'
require 'active_support/descendants_tracker'
require 'active_support/time'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/class/attribute_accessors'
require 'active_support/core_ext/class/delegating_attributes'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/array/extract_options'
require 'active_support/core_ext/hash/deep_merge'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/string/behavior'
require 'active_support/core_ext/kernel/singleton_class'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/module/introspection'
require 'active_support/core_ext/object/duplicable'
require 'active_support/core_ext/object/blank'
require 'active_support/deprecation'
require 'arel'
require 'active_record/errors'
require 'active_record/log_subscriber'
require 'active_record/explain_subscriber'

module ActiveRecord #:nodoc:
  # = Active Record
  #
  # Active Record objects don't specify their attributes directly, but rather infer them from
  # the table definition with which they're linked. Adding, removing, and changing attributes
  # and their type is done directly in the database. Any change is instantly reflected in the
  # Active Record objects. The mapping that binds a given Active Record class to a certain
  # database table will happen automatically in most common cases, but can be overwritten for the uncommon ones.
  #
  # See the mapping rules in table_name and the full example in link:files/activerecord/README_rdoc.html for more insight.
  #
  # == Creation
  #
  # Active Records accept constructor parameters either in a hash or as a block. The hash
  # method is especially useful when you're receiving the data from somewhere else, like an
  # HTTP request. It works like this:
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
  # Conditions can either be specified as a string, array, or hash representing the WHERE-part of an SQL statement.
  # The array form is to be used when the condition input is tainted and requires sanitization. The string form can
  # be used for statements that don't involve tainted data. The hash form works much like the array form, except
  # only equality and range is possible. Examples:
  #
  #   class User < ActiveRecord::Base
  #     def self.authenticate_unsafely(user_name, password)
  #       where("user_name = '#{user_name}' AND password = '#{password}'").first
  #     end
  #
  #     def self.authenticate_safely(user_name, password)
  #       where("user_name = ? AND password = ?", user_name, password).first
  #     end
  #
  #     def self.authenticate_safely_simply(user_name, password)
  #       where(:user_name => user_name, :password => password).first
  #     end
  #   end
  #
  # The <tt>authenticate_unsafely</tt> method inserts the parameters directly into the query
  # and is thus susceptible to SQL-injection attacks if the <tt>user_name</tt> and +password+
  # parameters come directly from an HTTP request. The <tt>authenticate_safely</tt> and
  # <tt>authenticate_safely_simply</tt> both will sanitize the <tt>user_name</tt> and +password+
  # before inserting them in the query, which will ensure that an attacker can't escape the
  # query and fake the login (or worse).
  #
  # When using multiple parameters in the conditions, it can easily become hard to read exactly
  # what the fourth or fifth question mark is supposed to represent. In those cases, you can
  # resort to named bind variables instead. That's done by replacing the question marks with
  # symbols and supplying a hash with values for the matching symbol keys:
  #
  #   Company.where(
  #     "id = :id AND name = :name AND division = :division AND created_at > :accounting_date",
  #     { :id => 3, :name => "37signals", :division => "First", :accounting_date => '2005-01-01' }
  #   ).first
  #
  # Similarly, a simple hash without a statement will generate conditions based on equality with the SQL AND
  # operator. For instance:
  #
  #   Student.where(:first_name => "Harvey", :status => 1)
  #   Student.where(params[:student])
  #
  # A range may be used in the hash to use the SQL BETWEEN operator:
  #
  #   Student.where(:grade => 9..12)
  #
  # An array may be used in the hash to use the SQL IN operator:
  #
  #   Student.where(:grade => [9,11,12])
  #
  # When joining tables, nested hashes or keys written in the form 'table_name.column_name'
  # can be used to qualify the table name of a particular condition. For instance:
  #
  #   Student.joins(:schools).where(:schools => { :category => 'public' })
  #   Student.joins(:schools).where('schools.category' => 'public' )
  #
  # == Overwriting default accessors
  #
  # All column values are automatically available through basic accessors on the Active Record
  # object, but sometimes you want to specialize this behavior. This can be done by overwriting
  # the default accessors (using the same name as the attribute) and calling
  # <tt>read_attribute(attr_name)</tt> and <tt>write_attribute(attr_name, value)</tt> to actually
  # change things.
  #
  #   class Song < ActiveRecord::Base
  #     # Uses an integer of seconds to hold the length of the song
  #
  #     def length=(minutes)
  #       write_attribute(:length, minutes.to_i * 60)
  #     end
  #
  #     def length
  #       read_attribute(:length) / 60
  #     end
  #   end
  #
  # You can alternatively use <tt>self[:attribute]=(value)</tt> and <tt>self[:attribute]</tt>
  # instead of <tt>write_attribute(:attribute, value)</tt> and <tt>read_attribute(:attribute)</tt>.
  #
  # == Attribute query methods
  #
  # In addition to the basic accessors, query methods are also automatically available on the Active Record object.
  # Query methods allow you to test whether an attribute value is present.
  #
  # For example, an Active Record User with the <tt>name</tt> attribute has a <tt>name?</tt> method that you can call
  # to determine whether the user has a name:
  #
  #   user = User.new(:name => "David")
  #   user.name? # => true
  #
  #   anonymous = User.new(:name => "")
  #   anonymous.name? # => false
  #
  # == Accessing attributes before they have been typecasted
  #
  # Sometimes you want to be able to read the raw attribute data without having the column-determined
  # typecast run its course first. That can be done by using the <tt><attribute>_before_type_cast</tt>
  # accessors that all attributes have. For example, if your Account model has a <tt>balance</tt> attribute,
  # you can call <tt>account.balance_before_type_cast</tt> or <tt>account.id_before_type_cast</tt>.
  #
  # This is especially useful in validation situations where the user might supply a string for an
  # integer field and you want to display the original string back in an error message. Accessing the
  # attribute normally would typecast the string to 0, which isn't what you want.
  #
  # == Dynamic attribute-based finders
  #
  # Dynamic attribute-based finders are a cleaner way of getting (and/or creating) objects
  # by simple queries without turning to SQL. They work by appending the name of an attribute
  # to <tt>find_by_</tt>, <tt>find_last_by_</tt>, or <tt>find_all_by_</tt> and thus produces finders
  # like <tt>Person.find_by_user_name</tt>, <tt>Person.find_all_by_last_name</tt>, and
  # <tt>Payment.find_by_transaction_id</tt>. Instead of writing
  # <tt>Person.where(:user_name => user_name).first</tt>, you just do <tt>Person.find_by_user_name(user_name)</tt>.
  # And instead of writing <tt>Person.where(:last_name => last_name).all</tt>, you just do
  # <tt>Person.find_all_by_last_name(last_name)</tt>.
  #
  # It's possible to add an exclamation point (!) on the end of the dynamic finders to get them to raise an
  # <tt>ActiveRecord::RecordNotFound</tt> error if they do not return any records,
  # like <tt>Person.find_by_last_name!</tt>.
  #
  # It's also possible to use multiple attributes in the same find by separating them with "_and_".
  #
  #  Person.where(:user_name => user_name, :password => password).first
  #  Person.find_by_user_name_and_password(user_name, password) # with dynamic finder
  #
  # It's even possible to call these dynamic finder methods on relations and named scopes.
  #
  #   Payment.order("created_on").find_all_by_amount(50)
  #   Payment.pending.find_last_by_amount(100)
  #
  # The same dynamic finder style can be used to create the object if it doesn't already exist.
  # This dynamic finder is called with <tt>find_or_create_by_</tt> and will return the object if
  # it already exists and otherwise creates it, then returns it. Protected attributes won't be set
  # unless they are given in a block.
  #
  #   # No 'Summer' tag exists
  #   Tag.find_or_create_by_name("Summer") # equal to Tag.create(:name => "Summer")
  #
  #   # Now the 'Summer' tag does exist
  #   Tag.find_or_create_by_name("Summer") # equal to Tag.find_by_name("Summer")
  #
  #   # Now 'Bob' exist and is an 'admin'
  #   User.find_or_create_by_name('Bob', :age => 40) { |u| u.admin = true }
  #
  # Adding an exclamation point (!) on to the end of <tt>find_or_create_by_</tt> will
  # raise an <tt>ActiveRecord::RecordInvalid</tt> error if the new record is invalid.
  #
  # Use the <tt>find_or_initialize_by_</tt> finder if you want to return a new record without
  # saving it first. Protected attributes won't be set unless they are given in a block.
  #
  #   # No 'Winter' tag exists
  #   winter = Tag.find_or_initialize_by_name("Winter")
  #   winter.persisted? # false
  #
  # To find by a subset of the attributes to be used for instantiating a new object, pass a hash instead of
  # a list of parameters.
  #
  #   Tag.find_or_create_by_name(:name => "rails", :creator => current_user)
  #
  # That will either find an existing tag named "rails", or create a new one while setting the
  # user that created it.
  #
  # Just like <tt>find_by_*</tt>, you can also use <tt>scoped_by_*</tt> to retrieve data. The good thing about
  # using this feature is that the very first time result is returned using <tt>method_missing</tt> technique
  # but after that the method is declared on the class. Henceforth <tt>method_missing</tt> will not be hit.
  #
  #  User.scoped_by_user_name('David')
  #
  # == Saving arrays, hashes, and other non-mappable objects in text columns
  #
  # Active Record can serialize any object in text columns using YAML. To do so, you must
  # specify this with a call to the class method +serialize+.
  # This makes it possible to store arrays, hashes, and other non-mappable objects without doing
  # any additional work.
  #
  #   class User < ActiveRecord::Base
  #     serialize :preferences
  #   end
  #
  #   user = User.create(:preferences => { "background" => "black", "display" => large })
  #   User.find(user.id).preferences # => { "background" => "black", "display" => large }
  #
  # You can also specify a class option as the second parameter that'll raise an exception
  # if a serialized object is retrieved as a descendant of a class not in the hierarchy.
  #
  #   class User < ActiveRecord::Base
  #     serialize :preferences, Hash
  #   end
  #
  #   user = User.create(:preferences => %w( one two three ))
  #   User.find(user.id).preferences    # raises SerializationTypeMismatch
  #
  # When you specify a class option, the default value for that attribute will be a new
  # instance of that class.
  #
  #   class User < ActiveRecord::Base
  #     serialize :preferences, OpenStruct
  #   end
  #
  #   user = User.new
  #   user.preferences.theme_color = "red"
  #
  #
  # == Single table inheritance
  #
  # Active Record allows inheritance by storing the name of the class in a column that by
  # default is named "type" (can be changed by overwriting <tt>Base.inheritance_column</tt>).
  # This means that an inheritance looking like this:
  #
  #   class Company < ActiveRecord::Base; end
  #   class Firm < Company; end
  #   class Client < Company; end
  #   class PriorityClient < Client; end
  #
  # When you do <tt>Firm.create(:name => "37signals")</tt>, this record will be saved in
  # the companies table with type = "Firm". You can then fetch this row again using
  # <tt>Company.where(:name => '37signals').first</tt> and it will return a Firm object.
  #
  # If you don't have a type column defined in your table, single-table inheritance won't
  # be triggered. In that case, it'll work just like normal subclasses with no special magic
  # for differentiating between them or reloading the right type with find.
  #
  # Note, all the attributes for all the cases are kept in the same table. Read more:
  # http://www.martinfowler.com/eaaCatalog/singleTableInheritance.html
  #
  # == Connection to multiple databases in different models
  #
  # Connections are usually created through ActiveRecord::Base.establish_connection and retrieved
  # by ActiveRecord::Base.connection. All classes inheriting from ActiveRecord::Base will use this
  # connection. But you can also set a class-specific connection. For example, if Course is an
  # ActiveRecord::Base, but resides in a different database, you can just say <tt>Course.establish_connection</tt>
  # and Course and all of its subclasses will use this connection instead.
  #
  # This feature is implemented by keeping a connection pool in ActiveRecord::Base that is
  # a Hash indexed by the class. If a connection is requested, the retrieve_connection method
  # will go up the class-hierarchy until a connection is found in the connection pool.
  #
  # == Exceptions
  #
  # * ActiveRecordError - Generic error class and superclass of all other errors raised by Active Record.
  # * AdapterNotSpecified - The configuration hash used in <tt>establish_connection</tt> didn't include an
  #   <tt>:adapter</tt> key.
  # * AdapterNotFound - The <tt>:adapter</tt> key used in <tt>establish_connection</tt> specified a
  #   non-existent adapter
  #   (or a bad spelling of an existing one).
  # * AssociationTypeMismatch - The object assigned to the association wasn't of the type
  #   specified in the association definition.
  # * SerializationTypeMismatch - The serialized object wasn't of the class specified as the second parameter.
  # * ConnectionNotEstablished+ - No connection has been established. Use <tt>establish_connection</tt>
  #   before querying.
  # * RecordNotFound - No record responded to the +find+ method. Either the row with the given ID doesn't exist
  #   or the row didn't meet the additional restrictions. Some +find+ calls do not raise this exception to signal
  #   nothing was found, please check its documentation for further details.
  # * StatementInvalid - The database server rejected the SQL statement. The precise error is added in the message.
  # * MultiparameterAssignmentErrors - Collection of errors that occurred during a mass assignment using the
  #   <tt>attributes=</tt> method. The +errors+ property of this exception contains an array of
  #   AttributeAssignmentError
  #   objects that should be inspected to determine which attributes triggered the errors.
  # * AttributeAssignmentError - An error occurred while doing a mass assignment through the
  #   <tt>attributes=</tt> method.
  #   You can inspect the +attribute+ property of the exception object to determine which attribute
  #   triggered the error.
  #
  # *Note*: The attributes listed are class-level attributes (accessible from both the class and instance level).
  # So it's possible to assign a logger to the class through <tt>Base.logger=</tt> which will then be used by all
  # instances in the current object space.
  class Base
    ##
    # :singleton-method:
    # Accepts a logger conforming to the interface of Log4r or the default Ruby 1.8+ Logger class,
    # which is then passed on to any new database connections made and which can be retrieved on both
    # a class and instance level by calling +logger+.
    cattr_accessor :logger, :instance_writer => false

    ##
    # :singleton-method:
    # Contains the database configuration - as is typically stored in config/database.yml -
    # as a Hash.
    #
    # For example, the following database.yml...
    #
    #   development:
    #     adapter: sqlite3
    #     database: db/development.sqlite3
    #
    #   production:
    #     adapter: sqlite3
    #     database: db/production.sqlite3
    #
    # ...would result in ActiveRecord::Base.configurations to look like this:
    #
    #   {
    #      'development' => {
    #         'adapter'  => 'sqlite3',
    #         'database' => 'db/development.sqlite3'
    #      },
    #      'production' => {
    #         'adapter'  => 'sqlite3',
    #         'database' => 'db/production.sqlite3'
    #      }
    #   }
    cattr_accessor :configurations, :instance_writer => false
    @@configurations = {}

    ##
    # :singleton-method:
    # Determines whether to use Time.local (using :local) or Time.utc (using :utc) when pulling
    # dates and times from the database. This is set to :local by default.
    cattr_accessor :default_timezone, :instance_writer => false
    @@default_timezone = :local

    ##
    # :singleton-method:
    # Specifies the format to use when dumping the database schema with Rails'
    # Rakefile. If :sql, the schema is dumped as (potentially database-
    # specific) SQL statements. If :ruby, the schema is dumped as an
    # ActiveRecord::Schema file which can be loaded into any database that
    # supports migrations. Use :ruby if you want to have different database
    # adapters for, e.g., your development and test environments.
    cattr_accessor :schema_format , :instance_writer => false
    @@schema_format = :ruby

    ##
    # :singleton-method:
    # Specify whether or not to use timestamps for migration versions
    cattr_accessor :timestamped_migrations , :instance_writer => false
    @@timestamped_migrations = true

    class << self # Class methods
      def inherited(child_class) #:nodoc:
        child_class.initialize_generated_modules
        super
      end

      def initialize_generated_modules #:nodoc:
        @attribute_methods_mutex = Mutex.new

        # force attribute methods to be higher in inheritance hierarchy than other generated methods
        generated_attribute_methods
        generated_feature_methods
      end

      def generated_feature_methods
        @generated_feature_methods ||= begin
          mod = const_set(:GeneratedFeatureMethods, Module.new)
          include mod
          mod
        end
      end

      # Returns a string like 'Post(id:integer, title:string, body:text)'
      def inspect
        if self == Base
          super
        elsif abstract_class?
          "#{super}(abstract)"
        elsif table_exists?
          attr_list = columns.map { |c| "#{c.name}: #{c.type}" } * ', '
          "#{super}(#{attr_list})"
        else
          "#{super}(Table doesn't exist)"
        end
      end

      # Overwrite the default class equality method to provide support for association proxies.
      def ===(object)
        object.is_a?(self)
      end

      def arel_table
        @arel_table ||= Arel::Table.new(table_name, arel_engine)
      end

      def arel_engine
        @arel_engine ||= begin
          if self == ActiveRecord::Base
            ActiveRecord::Base
          else
            connection_handler.retrieve_connection_pool(self) ? self : superclass.arel_engine
          end
        end
      end

      private

      def relation #:nodoc:
        relation = Relation.new(self, arel_table)

        if finder_needs_type_condition?
          relation.where(type_condition).create_with(inheritance_column.to_sym => sti_name)
        else
          relation
        end
      end
    end

    public
      # New objects can be instantiated as either empty (pass no construction parameter) or pre-set with
      # attributes but not yet saved (pass a hash with key names matching the associated table column names).
      # In both instances, valid attribute keys are determined by the column names of the associated table --
      # hence you can't have attributes that aren't part of the table columns.
      #
      # +initialize+ respects mass-assignment security and accepts either +:as+ or +:without_protection+ options
      # in the +options+ parameter.
      #
      # ==== Examples
      #   # Instantiates a single new object
      #   User.new(:first_name => 'Jamie')
      #
      #   # Instantiates a single new object using the :admin mass-assignment security role
      #   User.new({ :first_name => 'Jamie', :is_admin => true }, :as => :admin)
      #
      #   # Instantiates a single new object bypassing mass-assignment security
      #   User.new({ :first_name => 'Jamie', :is_admin => true }, :without_protection => true)
      def initialize(attributes = nil, options = {})
        @attributes = self.class.initialize_attributes(self.class.column_defaults.dup)
        @association_cache = {}
        @aggregation_cache = {}
        @attributes_cache = {}
        @new_record = true
        @readonly = false
        @destroyed = false
        @marked_for_destruction = false
        @previously_changed = {}
        @changed_attributes = {}

        ensure_proper_type

        populate_with_current_scope_attributes

        assign_attributes(attributes, options) if attributes

        yield self if block_given?
        run_callbacks :initialize
      end

      # Initialize an empty model object from +coder+. +coder+ must contain
      # the attributes necessary for initializing an empty model object. For
      # example:
      #
      #   class Post < ActiveRecord::Base
      #   end
      #
      #   post = Post.allocate
      #   post.init_with('attributes' => { 'title' => 'hello world' })
      #   post.title # => 'hello world'
      def init_with(coder)
        @attributes = self.class.initialize_attributes(coder['attributes'])
        @relation = nil

        @attributes_cache, @previously_changed, @changed_attributes = {}, {}, {}
        @association_cache = {}
        @aggregation_cache = {}
        @readonly = @destroyed = @marked_for_destruction = false
        @new_record = false
        run_callbacks :find
        run_callbacks :initialize

        self
      end

      # Duped objects have no id assigned and are treated as new records. Note
      # that this is a "shallow" copy as it copies the object's attributes
      # only, not its associations. The extent of a "deep" copy is application
      # specific and is therefore left to the application to implement according
      # to its need.
      # The dup method does not preserve the timestamps (created|updated)_(at|on).
      def initialize_dup(other)
        cloned_attributes = other.clone_attributes(:read_attribute_before_type_cast)
        self.class.initialize_attributes(cloned_attributes, :serialized => false)

        cloned_attributes.delete(self.class.primary_key)

        @attributes = cloned_attributes

        _run_after_initialize_callbacks if respond_to?(:_run_after_initialize_callbacks)

        @changed_attributes = {}
        self.class.column_defaults.each do |attr, orig_value|
          @changed_attributes[attr] = orig_value if _field_changed?(attr, orig_value, @attributes[attr])
        end

        @aggregation_cache = {}
        @association_cache = {}
        @attributes_cache = {}
        @new_record  = true

        ensure_proper_type
        populate_with_current_scope_attributes
        super
      end

      # Backport dup from 1.9 so that initialize_dup() gets called
      unless Object.respond_to?(:initialize_dup, true)
        def dup # :nodoc:
          copy = super
          copy.initialize_dup(self)
          copy
        end
      end

      # Populate +coder+ with attributes about this record that should be
      # serialized. The structure of +coder+ defined in this method is
      # guaranteed to match the structure of +coder+ passed to the +init_with+
      # method.
      #
      # Example:
      #
      #   class Post < ActiveRecord::Base
      #   end
      #   coder = {}
      #   Post.new.encode_with(coder)
      #   coder # => { 'id' => nil, ... }
      def encode_with(coder)
        coder['attributes'] = attributes
      end

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
          id.present? &&
          comparison_object.id == id
      end
      alias :eql? :==

      # Delegates to id in order to allow two records of the same type and id to work with something like:
      #   [ Person.find(1), Person.find(2), Person.find(3) ] & [ Person.find(1), Person.find(4) ] # => [ Person.find(1) ]
      def hash
        id.hash
      end

      # Freeze the attributes hash such that associations are still accessible, even on destroyed records.
      def freeze
        @attributes.freeze; self
      end

      # Returns +true+ if the attributes hash has been frozen.
      def frozen?
        @attributes.frozen?
      end

      # Allows sort on objects
      def <=>(other_object)
        if other_object.is_a?(self.class)
          self.to_key <=> other_object.to_key
        else
          nil
        end
      end

      # Returns +true+ if the record is read only. Records loaded through joins with piggy-back
      # attributes will be marked as read only since they cannot be saved.
      def readonly?
        @readonly
      end

      # Marks this record as read only.
      def readonly!
        @readonly = true
      end

      # Returns the contents of the record as a nicely formatted string.
      def inspect
        inspection = if @attributes
                       self.class.column_names.collect { |name|
                         if has_attribute?(name)
                           "#{name}: #{attribute_for_inspect(name)}"
                         end
                       }.compact.join(", ")
                     else
                       "not initialized"
                     end
        "#<#{self.class} #{inspection}>"
      end

      # Hackery to accomodate Syck. Remove for 4.0.
      def to_yaml(opts = {}) #:nodoc:
        if YAML.const_defined?(:ENGINE) && !YAML::ENGINE.syck?
          super
        else
          coder = {}
          encode_with(coder)
          YAML.quick_emit(self, opts) do |out|
            out.map(taguri, to_yaml_style) do |map|
              coder.each { |k, v| map.add(k, v) }
            end
          end
        end
      end

      # Hackery to accomodate Syck. Remove for 4.0.
      def yaml_initialize(tag, coder) #:nodoc:
        init_with(coder)
      end

    private

      # Under Ruby 1.9, Array#flatten will call #to_ary (recursively) on each of the elements
      # of the array, and then rescues from the possible NoMethodError. If those elements are
      # ActiveRecord::Base's, then this triggers the various method_missing's that we have,
      # which significantly impacts upon performance.
      #
      # So we can avoid the method_missing hit by explicitly defining #to_ary as nil here.
      #
      # See also http://tenderlovemaking.com/2011/06/28/til-its-ok-to-return-nil-from-to_ary/
      def to_ary # :nodoc:
        nil
      end

    include ActiveRecord::Persistence
    extend ActiveModel::Naming
    extend QueryCache::ClassMethods
    extend ActiveSupport::Benchmarkable
    extend ActiveSupport::DescendantsTracker

    extend Querying
    include ReadonlyAttributes
    include ModelSchema
    extend Translation
    include Inheritance
    include Scoping
    extend DynamicMatchers
    include Sanitization
    include AttributeAssignment
    include ActiveModel::Conversion
    include Integration
    include Validations
    extend CounterCache
    include Locking::Optimistic, Locking::Pessimistic
    include AttributeMethods
    include Callbacks, ActiveModel::Observing, Timestamp
    include Associations
    include IdentityMap
    include ActiveModel::SecurePassword
    extend Explain

    # AutosaveAssociation needs to be included before Transactions, because we want
    # #save_with_autosave_associations to be wrapped inside a transaction.
    include AutosaveAssociation, NestedAttributes
    include Aggregations, Transactions, Reflection, Serialization, Store
  end
end

require 'active_record/connection_adapters/abstract/connection_specification'
ActiveSupport.run_load_hooks(:active_record, ActiveRecord::Base)
