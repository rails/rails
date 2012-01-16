require 'active_support/concern'

module ActiveRecord
  module Core
    extend ActiveSupport::Concern

    included do
      ##
      # :singleton-method:
      # Accepts a logger conforming to the interface of Log4r or the default Ruby 1.8+ Logger class,
      # which is then passed on to any new database connections made and which can be retrieved on both
      # a class and instance level by calling +logger+.
      config_attribute :logger, :global => true

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
      config_attribute :configurations, :global => true
      self.configurations = {}

      ##
      # :singleton-method:
      # Determines whether to use Time.local (using :local) or Time.utc (using :utc) when pulling
      # dates and times from the database. This is set to :local by default.
      config_attribute :default_timezone, :global => true
      self.default_timezone = :local

      ##
      # :singleton-method:
      # Specifies the format to use when dumping the database schema with Rails'
      # Rakefile. If :sql, the schema is dumped as (potentially database-
      # specific) SQL statements. If :ruby, the schema is dumped as an
      # ActiveRecord::Schema file which can be loaded into any database that
      # supports migrations. Use :ruby if you want to have different database
      # adapters for, e.g., your development and test environments.
      config_attribute :schema_format, :global => true
      self.schema_format = :ruby

      ##
      # :singleton-method:
      # Specify whether or not to use timestamps for migration versions
      config_attribute :timestamped_migrations, :global => true
      self.timestamped_migrations = true

      ##
      # :singleton-method:
      # The connection handler
      config_attribute :connection_handler
      self.connection_handler = ConnectionAdapters::ConnectionHandler.new
    end

    module ClassMethods
      def inherited(child_class) #:nodoc:
        child_class.initialize_generated_modules
        super
      end

      def initialize_generated_modules
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
        @arel_engine ||= connection_handler.connection_pools[name] ? self : active_record_super.arel_engine
      end

      private

      def relation #:nodoc:
        @relation ||= Relation.new(self, arel_table)

        if finder_needs_type_condition?
          @relation.where(type_condition).create_with(inheritance_column.to_sym => sti_name)
        else
          @relation
        end
      end
    end

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
      @relation = nil

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
      cloned_attributes.delete(self.class.primary_key)

      @attributes = cloned_attributes

      run_callbacks(:initialize) if _initialize_callbacks.any?

      @changed_attributes = {}
      self.class.column_defaults.each do |attr, orig_value|
        @changed_attributes[attr] = orig_value if field_changed?(attr, orig_value, @attributes[attr])
      end

      @aggregation_cache = {}
      @association_cache = {}
      @attributes_cache = {}
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
  end
end
