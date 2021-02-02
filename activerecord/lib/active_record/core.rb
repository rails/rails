# frozen_string_literal: true

require "active_support/core_ext/enumerable"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/string/filters"
require "active_support/parameter_filter"
require "concurrent/map"

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
      #
      # Specifies if the methods calling database queries should be logged below
      # their relevant queries. Defaults to false.
      mattr_accessor :verbose_query_logs, instance_writer: false, default: false

      ##
      # :singleton-method:
      #
      # Specifies the names of the queues used by background jobs.
      mattr_accessor :queues, instance_accessor: false, default: {}

      ##
      # :singleton-method:
      #
      # Specifies the job used to destroy associations in the background
      class_attribute :destroy_association_async_job, instance_writer: false, instance_predicate: false, default: false

      ##
      # Contains the database configuration - as is typically stored in config/database.yml -
      # as an ActiveRecord::DatabaseConfigurations object.
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
      #   #<ActiveRecord::DatabaseConfigurations:0x00007fd1acbdf800 @configurations=[
      #     #<ActiveRecord::DatabaseConfigurations::HashConfig:0x00007fd1acbded10 @env_name="development",
      #       @name="primary", @config={adapter: "sqlite3", database: "db/development.sqlite3"}>,
      #     #<ActiveRecord::DatabaseConfigurations::HashConfig:0x00007fd1acbdea90 @env_name="production",
      #       @name="primary", @config={adapter: "sqlite3", database: "db/production.sqlite3"}>
      #   ]>
      def self.configurations=(config)
        @@configurations = ActiveRecord::DatabaseConfigurations.new(config)
      end
      self.configurations = {}

      # Returns fully resolved ActiveRecord::DatabaseConfigurations object
      def self.configurations
        @@configurations
      end

      ##
      # :singleton-method:
      # Determines whether to use Time.utc (using :utc) or Time.local (using :local) when pulling
      # dates and times from the database. This is set to :utc by default.
      mattr_accessor :default_timezone, instance_writer: false, default: :utc

      ##
      # :singleton-method:
      # Specifies the format to use when dumping the database schema with Rails'
      # Rakefile. If :sql, the schema is dumped as (potentially database-
      # specific) SQL statements. If :ruby, the schema is dumped as an
      # ActiveRecord::Schema file which can be loaded into any database that
      # supports migrations. Use :ruby if you want to have different database
      # adapters for, e.g., your development and test environments.
      mattr_accessor :schema_format, instance_writer: false, default: :ruby

      ##
      # :singleton-method:
      # Specifies if an error should be raised if the query has an order being
      # ignored when doing batch queries. Useful in applications where the
      # scope being ignored is error-worthy, rather than a warning.
      mattr_accessor :error_on_ignored_order, instance_writer: false, default: false

      ##
      # :singleton-method:
      # Specify whether or not to use timestamps for migration versions
      mattr_accessor :timestamped_migrations, instance_writer: false, default: true

      ##
      # :singleton-method:
      # Specify whether schema dump should happen at the end of the
      # db:migrate rails command. This is true by default, which is useful for the
      # development environment. This should ideally be false in the production
      # environment where dumping schema is rarely needed.
      mattr_accessor :dump_schema_after_migration, instance_writer: false, default: true

      ##
      # :singleton-method:
      # Specifies which database schemas to dump when calling db:schema:dump.
      # If the value is :schema_search_path (the default), any schemas listed in
      # schema_search_path are dumped. Use :all to dump all schemas regardless
      # of schema_search_path, or a string of comma separated schemas for a
      # custom list.
      mattr_accessor :dump_schemas, instance_writer: false, default: :schema_search_path

      ##
      # :singleton-method:
      # Specify a threshold for the size of query result sets. If the number of
      # records in the set exceeds the threshold, a warning is logged. This can
      # be used to identify queries which load thousands of records and
      # potentially cause memory bloat.
      mattr_accessor :warn_on_records_fetched_greater_than, instance_writer: false

      ##
      # :singleton-method:
      # Show a warning when Rails couldn't parse your database.yml
      # for multiple databases.
      mattr_accessor :suppress_multiple_database_warning, instance_writer: false, default: false

      mattr_accessor :maintain_test_schema, instance_accessor: false

      class_attribute :belongs_to_required_by_default, instance_accessor: false

      ##
      # :singleton-method:
      # Set the application to log or raise when an association violates strict loading.
      # Defaults to :raise.
      mattr_accessor :action_on_strict_loading_violation, instance_accessor: false, default: :raise

      class_attribute :strict_loading_by_default, instance_accessor: false, default: false

      mattr_accessor :writing_role, instance_accessor: false, default: :writing

      mattr_accessor :reading_role, instance_accessor: false, default: :reading

      mattr_accessor :has_many_inversing, instance_accessor: false, default: false

      class_attribute :default_connection_handler, instance_writer: false

      class_attribute :default_role, instance_writer: false

      class_attribute :default_shard, instance_writer: false

      mattr_accessor :legacy_connection_handling, instance_writer: false, default: true

      self.filter_attributes = []

      def self.connection_handler
        Thread.current.thread_variable_get(:ar_connection_handler) || default_connection_handler
      end

      def self.connection_handler=(handler)
        Thread.current.thread_variable_set(:ar_connection_handler, handler)
      end

      def self.connection_handlers
        unless legacy_connection_handling
          raise NotImplementedError, "The new connection handling does not support accessing multiple connection handlers."
        end

        @@connection_handlers ||= {}
      end

      def self.connection_handlers=(handlers)
        unless legacy_connection_handling
          raise NotImplementedError, "The new connection handling does not setting support multiple connection handlers."
        end

        @@connection_handlers = handlers
      end

      # Returns the symbol representing the current connected role.
      #
      #   ActiveRecord::Base.connected_to(role: :writing) do
      #     ActiveRecord::Base.current_role #=> :writing
      #   end
      #
      #   ActiveRecord::Base.connected_to(role: :reading) do
      #     ActiveRecord::Base.current_role #=> :reading
      #   end
      def self.current_role
        if ActiveRecord::Base.legacy_connection_handling
          connection_handlers.key(connection_handler) || default_role
        else
          connected_to_stack.reverse_each do |hash|
            return hash[:role] if hash[:role] && hash[:klasses].include?(Base)
            return hash[:role] if hash[:role] && hash[:klasses].include?(connection_classes)
          end

          default_role
        end
      end

      # Returns the symbol representing the current connected shard.
      #
      #   ActiveRecord::Base.connected_to(role: :reading) do
      #     ActiveRecord::Base.current_shard #=> :default
      #   end
      #
      #   ActiveRecord::Base.connected_to(role: :writing, shard: :one) do
      #     ActiveRecord::Base.current_shard #=> :one
      #   end
      def self.current_shard
        connected_to_stack.reverse_each do |hash|
          return hash[:shard] if hash[:shard] && hash[:klasses].include?(Base)
          return hash[:shard] if hash[:shard] && hash[:klasses].include?(connection_classes)
        end

        default_shard
      end

      # Returns the symbol representing the current setting for
      # preventing writes.
      #
      #   ActiveRecord::Base.connected_to(role: :reading) do
      #     ActiveRecord::Base.current_preventing_writes #=> true
      #   end
      #
      #   ActiveRecord::Base.connected_to(role: :writing) do
      #     ActiveRecord::Base.current_preventing_writes #=> false
      #   end
      def self.current_preventing_writes
        if legacy_connection_handling
          connection_handler.prevent_writes
        else
          connected_to_stack.reverse_each do |hash|
            return hash[:prevent_writes] if !hash[:prevent_writes].nil? && hash[:klasses].include?(Base)
            return hash[:prevent_writes] if !hash[:prevent_writes].nil? && hash[:klasses].include?(connection_classes)
          end

          false
        end
      end

      def self.connected_to_stack # :nodoc:
        if connected_to_stack = Thread.current.thread_variable_get(:ar_connected_to_stack)
          connected_to_stack
        else
          connected_to_stack = Concurrent::Array.new
          Thread.current.thread_variable_set(:ar_connected_to_stack, connected_to_stack)
          connected_to_stack
        end
      end

      def self.connection_class=(b) # :nodoc:
        @connection_class = b
      end

      def self.connection_class # :nodoc
        @connection_class ||= false
      end

      def self.connection_class? # :nodoc:
        self.connection_class
      end

      def self.connection_classes # :nodoc:
        klass = self

        until klass == Base
          break if klass.connection_class?
          klass = klass.superclass
        end

        klass
      end

      def self.allow_unsafe_raw_sql # :nodoc:
        ActiveSupport::Deprecation.warn("ActiveRecord::Base.allow_unsafe_raw_sql is deprecated and will be removed in Rails 6.2")
      end

      def self.allow_unsafe_raw_sql=(value) # :nodoc:
        ActiveSupport::Deprecation.warn("ActiveRecord::Base.allow_unsafe_raw_sql= is deprecated and will be removed in Rails 6.2")
      end

      self.default_connection_handler = ConnectionAdapters::ConnectionHandler.new
      self.default_role = writing_role
      self.default_shard = :default

      def self.strict_loading_violation!(owner:, reflection:) # :nodoc:
        case action_on_strict_loading_violation
        when :raise
          message = "`#{owner}` is marked for strict_loading. The `#{reflection.klass}` association named `:#{reflection.name}` cannot be lazily loaded."
          raise ActiveRecord::StrictLoadingViolationError.new(message)
        when :log
          name = "strict_loading_violation.active_record"
          ActiveSupport::Notifications.instrument(name, owner: owner, reflection: reflection)
        end
      end
    end

    module ClassMethods
      def initialize_find_by_cache # :nodoc:
        @find_by_statement_cache = { true => Concurrent::Map.new, false => Concurrent::Map.new }
      end

      def inherited(child_class) # :nodoc:
        # initialize cache at class definition for thread safety
        child_class.initialize_find_by_cache
        unless child_class.base_class?
          klass = self
          until klass.base_class?
            klass.initialize_find_by_cache
            klass = klass.superclass
          end
        end
        super
      end

      def find(*ids) # :nodoc:
        # We don't have cache keys for this stuff yet
        return super unless ids.length == 1
        return super if block_given? || primary_key.nil? || scope_attributes?

        id = ids.first

        return super if StatementCache.unsupported_value?(id)

        key = primary_key

        statement = cached_find_by_statement(key) { |params|
          where(key => params.bind).limit(1)
        }

        statement.execute([id], connection).first ||
          raise(RecordNotFound.new("Couldn't find #{name} with '#{key}'=#{id}", name, key, id))
      end

      def find_by(*args) # :nodoc:
        return super if scope_attributes?

        hash = args.first
        return super unless Hash === hash

        hash = hash.each_with_object({}) do |(key, value), h|
          key = key.to_s
          key = attribute_aliases[key] || key

          return super if reflect_on_aggregation(key)

          reflection = _reflect_on_association(key)

          if !reflection
            value = value.id if value.respond_to?(:id)
          elsif reflection.belongs_to? && !reflection.polymorphic?
            key = reflection.join_foreign_key
            pkey = reflection.join_primary_key
            value = value.public_send(pkey) if value.respond_to?(pkey)
          end

          if !columns_hash.key?(key) || StatementCache.unsupported_value?(value)
            return super
          end

          h[key] = value
        end

        keys = hash.keys
        statement = cached_find_by_statement(keys) { |params|
          wheres = keys.index_with { params.bind }
          where(wheres).limit(1)
        }

        begin
          statement.execute(hash.values, connection).first
        rescue TypeError
          raise ActiveRecord::StatementInvalid
        end
      end

      def find_by!(*args) # :nodoc:
        find_by(*args) || raise(RecordNotFound.new("Couldn't find #{name}", name))
      end

      def initialize_generated_modules # :nodoc:
        generated_association_methods
      end

      def generated_association_methods # :nodoc:
        @generated_association_methods ||= begin
          mod = const_set(:GeneratedAssociationMethods, Module.new)
          private_constant :GeneratedAssociationMethods
          include mod

          mod
        end
      end

      # Returns columns which shouldn't be exposed while calling +#inspect+.
      def filter_attributes
        if defined?(@filter_attributes)
          @filter_attributes
        else
          superclass.filter_attributes
        end
      end

      # Specifies columns which shouldn't be exposed while calling +#inspect+.
      attr_writer :filter_attributes

      # Returns a string like 'Post(id:integer, title:string, body:text)'
      def inspect # :nodoc:
        if self == Base
          super
        elsif abstract_class?
          "#{super}(abstract)"
        elsif !connected?
          "#{super} (call '#{super}.connection' to establish a connection)"
        elsif table_exists?
          attr_list = attribute_types.map { |name, type| "#{name}: #{type.type}" } * ", "
          "#{super}(#{attr_list})"
        else
          "#{super}(Table doesn't exist)"
        end
      end

      # Overwrite the default class equality method to provide support for decorated models.
      def ===(object) # :nodoc:
        object.is_a?(self)
      end

      # Returns an instance of <tt>Arel::Table</tt> loaded with the current table name.
      def arel_table # :nodoc:
        @arel_table ||= Arel::Table.new(table_name, klass: self)
      end

      def arel_attribute(name, table = arel_table) # :nodoc:
        table[name]
      end
      deprecate :arel_attribute

      def predicate_builder # :nodoc:
        @predicate_builder ||= PredicateBuilder.new(table_metadata)
      end

      def type_caster # :nodoc:
        TypeCaster::Map.new(self)
      end

      def cached_find_by_statement(key, &block) # :nodoc:
        cache = @find_by_statement_cache[connection.prepared_statements]
        cache.compute_if_absent(key) { StatementCache.create(connection, &block) }
      end

      private
        def relation
          relation = Relation.create(self)

          if finder_needs_type_condition? && !ignore_default_scope?
            relation.where!(type_condition)
          else
            relation
          end
        end

        def table_metadata
          TableMetadata.new(self, arel_table)
        end
    end

    # New objects can be instantiated as either empty (pass no construction parameter) or pre-set with
    # attributes but not yet saved (pass a hash with key names matching the associated table column names).
    # In both instances, valid attribute keys are determined by the column names of the associated table --
    # hence you can't have attributes that aren't part of the table columns.
    #
    # ==== Example:
    #   # Instantiates a single new object
    #   User.new(first_name: 'Jamie')
    def initialize(attributes = nil)
      @new_record = true
      @attributes = self.class._default_attributes.deep_dup

      init_internals
      initialize_internals_callback

      assign_attributes(attributes) if attributes

      yield self if block_given?
      _run_initialize_callbacks
    end

    # Initialize an empty model object from +coder+. +coder+ should be
    # the result of previously encoding an Active Record model, using
    # #encode_with.
    #
    #   class Post < ActiveRecord::Base
    #   end
    #
    #   old_post = Post.new(title: "hello world")
    #   coder = {}
    #   old_post.encode_with(coder)
    #
    #   post = Post.allocate
    #   post.init_with(coder)
    #   post.title # => 'hello world'
    def init_with(coder, &block)
      coder = LegacyYamlAdapter.convert(self.class, coder)
      attributes = self.class.yaml_encoder.decode(coder)
      init_with_attributes(attributes, coder["new_record"], &block)
    end

    ##
    # Initialize an empty model object from +attributes+.
    # +attributes+ should be an attributes object, and unlike the
    # `initialize` method, no assignment calls are made per attribute.
    def init_with_attributes(attributes, new_record = false) # :nodoc:
      @new_record = new_record
      @attributes = attributes

      init_internals

      yield self if block_given?

      _run_find_callbacks
      _run_initialize_callbacks

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
      @attributes = @attributes.deep_dup
      @attributes.reset(@primary_key)

      _run_initialize_callbacks

      @new_record               = true
      @previously_new_record    = false
      @destroyed                = false
      @_start_transaction_state = nil

      super
    end

    # Populate +coder+ with attributes about this record that should be
    # serialized. The structure of +coder+ defined in this method is
    # guaranteed to match the structure of +coder+ passed to the #init_with
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
      self.class.yaml_encoder.encode(@attributes, coder)
      coder["new_record"] = new_record?
      coder["active_record_yaml_version"] = 2
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
        !id.nil? &&
        comparison_object.id == id
    end
    alias :eql? :==

    # Delegates to id in order to allow two records of the same type and id to work with something like:
    #   [ Person.find(1), Person.find(2), Person.find(3) ] & [ Person.find(1), Person.find(4) ] # => [ Person.find(1) ]
    def hash
      if id
        self.class.hash ^ id.hash
      else
        super
      end
    end

    # Clone and freeze the attributes hash such that associations are still
    # accessible, even on destroyed records, but cloned models will not be
    # frozen.
    def freeze
      @attributes = @attributes.clone.freeze
      self
    end

    # Returns +true+ if the attributes hash has been frozen.
    def frozen?
      @attributes.frozen?
    end

    # Allows sort on objects
    def <=>(other_object)
      if other_object.is_a?(self.class)
        to_key <=> other_object.to_key
      else
        super
      end
    end

    def present? # :nodoc:
      true
    end

    def blank? # :nodoc:
      false
    end

    # Returns +true+ if the record is read only.
    def readonly?
      @readonly
    end

    # Returns +true+ if the record is in strict_loading mode.
    def strict_loading?
      @strict_loading
    end

    # Sets the record to strict_loading mode. This will raise an error
    # if the record tries to lazily load an association.
    #
    #   user = User.first
    #   user.strict_loading! # => true
    #   user.comments
    #   => ActiveRecord::StrictLoadingViolationError
    #
    # strict_loading! accepts a boolean argument to specify whether
    # to enable or disable strict loading mode.
    #
    #   user = User.first
    #   user.strict_loading!(false) # => false
    #   user.comments
    #   => #<ActiveRecord::Associations::CollectionProxy>
    def strict_loading!(value = true)
      @strict_loading = value
    end

    # Marks this record as read only.
    def readonly!
      @readonly = true
    end

    def connection_handler
      self.class.connection_handler
    end

    # Returns the contents of the record as a nicely formatted string.
    def inspect
      # We check defined?(@attributes) not to issue warnings if the object is
      # allocated but not initialized.
      inspection = if defined?(@attributes) && @attributes
        self.class.attribute_names.collect do |name|
          if _has_attribute?(name)
            "#{name}: #{attribute_for_inspect(name)}"
          end
        end.compact.join(", ")
      else
        "not initialized"
      end

      "#<#{self.class} #{inspection}>"
    end

    # Takes a PP and prettily prints this record to it, allowing you to get a nice result from <tt>pp record</tt>
    # when pp is required.
    def pretty_print(pp)
      return super if custom_inspect_method_defined?
      pp.object_address_group(self) do
        if defined?(@attributes) && @attributes
          attr_names = self.class.attribute_names.select { |name| _has_attribute?(name) }
          pp.seplist(attr_names, proc { pp.text "," }) do |attr_name|
            pp.breakable " "
            pp.group(1) do
              pp.text attr_name
              pp.text ":"
              pp.breakable
              value = _read_attribute(attr_name)
              value = inspection_filter.filter_param(attr_name, value) unless value.nil?
              pp.pp value
            end
          end
        else
          pp.breakable " "
          pp.text "not initialized"
        end
      end
    end

    # Returns a hash of the given methods with their names as keys and returned values as values.
    def slice(*methods)
      methods.flatten.index_with { |method| public_send(method) }.with_indifferent_access
    end

    # Returns an array of the values returned by the given methods.
    def values_at(*methods)
      methods.flatten.map! { |method| public_send(method) }
    end

    private
      # +Array#flatten+ will call +#to_ary+ (recursively) on each of the elements of
      # the array, and then rescues from the possible +NoMethodError+. If those elements are
      # +ActiveRecord::Base+'s, then this triggers the various +method_missing+'s that we have,
      # which significantly impacts upon performance.
      #
      # So we can avoid the +method_missing+ hit by explicitly defining +#to_ary+ as +nil+ here.
      #
      # See also https://tenderlovemaking.com/2011/06/28/til-its-ok-to-return-nil-from-to_ary.html
      def to_ary
        nil
      end

      def init_internals
        @primary_key              = self.class.primary_key
        @readonly                 = false
        @previously_new_record    = false
        @destroyed                = false
        @marked_for_destruction   = false
        @destroyed_by_association = nil
        @_start_transaction_state = nil
        @strict_loading           = self.class.strict_loading_by_default

        self.class.define_attribute_methods
      end

      def initialize_internals_callback
      end

      def custom_inspect_method_defined?
        self.class.instance_method(:inspect).owner != ActiveRecord::Base.instance_method(:inspect).owner
      end

      class InspectionMask < DelegateClass(::String)
        def pretty_print(pp)
          pp.text __getobj__
        end
      end
      private_constant :InspectionMask

      def inspection_filter
        @inspection_filter ||= begin
          mask = InspectionMask.new(ActiveSupport::ParameterFilter::FILTERED)
          ActiveSupport::ParameterFilter.new(self.class.filter_attributes, mask: mask)
        end
      end
  end
end
