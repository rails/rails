require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/object/duplicable'
require 'thread'

module ActiveRecord
  module Core
    extend ActiveSupport::Concern

    included do
      ##
      # :singleton-method:
      #
      # Accepts a logger conforming to the interface of Log4r which is then
      # passed on to any new database connections made and which can be
      # retrieved on both a class and instance level by calling +logger+.
      mattr_accessor :logger, instance_writer: false

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
      mattr_accessor :configurations, instance_writer: false
      self.configurations = {}

      ##
      # :singleton-method:
      # Determines whether to use Time.utc (using :utc) or Time.local (using :local) when pulling
      # dates and times from the database. This is set to :utc by default.
      mattr_accessor :default_timezone, instance_writer: false
      self.default_timezone = :utc

      ##
      # :singleton-method:
      # Specifies the format to use when dumping the database schema with Rails'
      # Rakefile. If :sql, the schema is dumped as (potentially database-
      # specific) SQL statements. If :ruby, the schema is dumped as an
      # ActiveRecord::Schema file which can be loaded into any database that
      # supports migrations. Use :ruby if you want to have different database
      # adapters for, e.g., your development and test environments.
      mattr_accessor :schema_format, instance_writer: false
      self.schema_format = :ruby

      ##
      # :singleton-method:
      # Specify whether or not to use timestamps for migration versions
      mattr_accessor :timestamped_migrations, instance_writer: false
      self.timestamped_migrations = true

      class_attribute :connection_handler, instance_writer: false
      self.connection_handler = ConnectionAdapters::ConnectionHandler.new
    end

    module ClassMethods
      def inherited(child_class) #:nodoc:
        child_class.initialize_generated_modules
        super
      end

      def initialize_generated_modules
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

      # Returns an instance of <tt>Arel::Table</tt> loaded with the current table name.
      #
      #   class Post < ActiveRecord::Base
      #     scope :published_and_commented, published.and(self.arel_table[:comments_count].gt(0))
      #   end
      def arel_table
        @arel_table ||= Arel::Table.new(table_name, arel_engine)
      end

      # Returns the Arel engine.
      def arel_engine
        @arel_engine ||= begin
          if Base == self || connection_handler.retrieve_connection_pool(self)
            self
          else
            superclass.arel_engine
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

    # New objects can be instantiated as either empty (pass no construction parameter) or pre-set with
    # attributes but not yet saved (pass a hash with key names matching the associated table column names).
    # In both instances, valid attribute keys are determined by the column names of the associated table --
    # hence you can't have attributes that aren't part of the table columns.
    #
    # ==== Example:
    #   # Instantiates a single new object
    #   User.new(:first_name => 'Jamie')
    def initialize(attributes = nil)
      defaults = self.class.column_defaults.dup
      defaults.each { |k, v| defaults[k] = v.dup if v.duplicable? }

      @attributes   = self.class.initialize_attributes(defaults)
      @columns_hash = self.class.column_types.dup

      init_internals
      ensure_proper_type
      populate_with_current_scope_attributes

      assign_attributes(attributes) if attributes

      yield self if block_given?
      run_callbacks :initialize unless _initialize_callbacks.empty?
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
      @attributes   = self.class.initialize_attributes(coder['attributes'])
      @columns_hash = self.class.column_types.merge(coder['column_types'] || {})

      init_internals

      @new_record = false

      run_callbacks :find
      run_callbacks :initialize

      self
    end

    ##
    # :method: clone
    # Identical to Ruby's clone method.  This is a "shallow" copy.  Be warned that your attributes are not copied.
    # That means that modifying attributes of the clone will modify the original, since they will both point to the
    # same attributes hash. If you need a copy of your attributes hash, please use the #dup method.
    #
    #   user = User.first
    #   new_user = user.clone
    #   user.name               # => "Bob"
    #   new_user.name = "Joe"
    #   user.name               # => "Joe"
    #
    #   user.object_id == new_user.object_id            # => false
    #   user.name.object_id == new_user.name.object_id  # => true
    #
    #   user.name.object_id == user.dup.name.object_id  # => false

    ##
    # :method: dup
    # Duped objects have no id assigned and are treated as new records. Note
    # that this is a "shallow" copy as it copies the object's attributes
    # only, not its associations. The extent of a "deep" copy is application
    # specific and is therefore left to the application to implement according
    # to its need.
    # The dup method does not preserve the timestamps (created|updated)_(at|on).

    ##
    def initialize_dup(other) # :nodoc:
      cloned_attributes = other.clone_attributes(:read_attribute_before_type_cast)
      self.class.initialize_attributes(cloned_attributes, :serialized => false)

      @attributes = cloned_attributes
      @attributes[self.class.primary_key] = nil

      run_callbacks(:initialize) unless _initialize_callbacks.empty?

      @changed_attributes = {}
      self.class.column_defaults.each do |attr, orig_value|
        @changed_attributes[attr] = orig_value if _field_changed?(attr, orig_value, @attributes[attr])
      end

      @aggregation_cache = {}
      @association_cache = {}
      @attributes_cache  = {}

      @new_record  = true

      ensure_proper_type
      populate_with_current_scope_attributes
      super
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
    #   coder # => {"attributes" => {"id" => nil, ... }}
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
      @attributes.freeze
      self
    end

    # Returns +true+ if the attributes hash has been frozen.
    def frozen?
      @attributes.frozen?
    end

    # Allows sort on objects
    def <=>(other_object)
      if other_object.is_a?(self.class)
        self.to_key <=> other_object.to_key
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

    # Returns the connection currently associated with the class. This can
    # also be used to "borrow" the connection to do database work that isn't
    # easily done without going straight to SQL.
    def connection
      self.class.connection
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

    # Returns a hash of the given methods with their names as keys and returned values as values.
    def slice(*methods)
      Hash[methods.map { |method| [method, public_send(method)] }].with_indifferent_access
    end

    private

    # Under Ruby 1.9, Array#flatten will call #to_ary (recursively) on each of the elements
    # of the array, and then rescues from the possible NoMethodError. If those elements are
    # ActiveRecord::Base's, then this triggers the various method_missing's that we have,
    # which significantly impacts upon performance.
    #
    # So we can avoid the method_missing hit by explicitly defining #to_ary as nil here.
    #
    # See also http://tenderlovemaking.com/2011/06/28/til-its-ok-to-return-nil-from-to_ary.html
    def to_ary # :nodoc:
      nil
    end

    def init_internals
      pk = self.class.primary_key
      @attributes[pk] = nil unless @attributes.key?(pk)

      @aggregation_cache       = {}
      @association_cache       = {}
      @attributes_cache        = {}
      @previously_changed      = {}
      @changed_attributes      = {}
      @readonly                = false
      @destroyed               = false
      @marked_for_destruction  = false
      @new_record              = true
      @txn                     = nil
      @_start_transaction_state = {}
    end
  end
end
