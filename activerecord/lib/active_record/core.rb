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

      # :singleton-method:
      # Specify the behavior for unsafe raw query methods. Values are as follows
      #   deprecated - Warnings are logged when unsafe raw SQL is passed to
      #                query methods.
      #   disabled   - Unsafe raw SQL passed to query methods results in
      #                UnknownAttributeReference exception.
      mattr_accessor :allow_unsafe_raw_sql, instance_writer: false, default: :deprecated

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
      # Specifies which database schemas to dump when calling db:structure:dump.
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

      mattr_accessor :maintain_test_schema, instance_accessor: false

      class_attribute :belongs_to_required_by_default, instance_accessor: false

      class_attribute :strict_loading_by_default, instance_accessor: false, default: false

      mattr_accessor :connection_handlers, instance_accessor: false, default: {}

      mattr_accessor :writing_role, instance_accessor: false, default: :writing

      mattr_accessor :reading_role, instance_accessor: false, default: :reading

      mattr_accessor :has_many_inversing, instance_accessor: false, default: false

      class_attribute :default_connection_handler, instance_writer: false

      class_attribute :default_pool_key, instance_writer: false

      self.filter_attributes = []

      def self.connection_handler
        Thread.current.thread_variable_get(:ar_connection_handler) || default_connection_handler
      end

      def self.connection_handler=(handler)
        Thread.current.thread_variable_set(:ar_connection_handler, handler)
      end

      def self.current_pool_key
        Thread.current.thread_variable_get(:ar_pool_key) || default_pool_key
      end

      def self.current_pool_key=(pool_key)
        Thread.current.thread_variable_set(:ar_pool_key, pool_key)
      end

      self.default_connection_handler = ConnectionAdapters::ConnectionHandler.new
      self.default_pool_key = :default
    end

    module ClassMethods
      def initialize_find_by_cache # :nodoc:
        @find_by_statement_cache = { true => Concurrent::Map.new, false => Concurrent::Map.new }
      end

      def inherited(child_class) # :nodoc:
        # initialize cache at class definition for thread safety
        child_class.initialize_find_by_cache
        super
      end

      def find(*ids) # :nodoc:
        # We don't have cache keys for this stuff yet
        return super unless ids.length == 1
        return super if block_given? ||
                        primary_key.nil? ||
                        scope_attributes? ||
                        columns_hash.key?(inheritance_column) && !base_class?

        id = ids.first

        return super if StatementCache.unsupported_value?(id)

        key = primary_key

        statement = cached_find_by_statement(key) { |params|
          where(key => params.bind).limit(1)
        }

        record = statement.execute([id], connection)&.first
        unless record
          raise RecordNotFound.new("Couldn't find #{name} with '#{key}'=#{id}", name, key, id)
        end
        record
      end

      def find_by(*args) # :nodoc:
        return super if scope_attributes? || reflect_on_all_aggregations.any? ||
                        columns_hash.key?(inheritance_column) && !base_class?

        hash = args.first
        return super unless Hash === hash

        values = hash.values
        return super if values.any? { |v| StatementCache.unsupported_value?(v) }

        # We can't cache Post.find_by(author: david) ...yet
        keys = hash.keys.map! { |key| attribute_aliases[name = key.to_s] || name }
        return super unless keys.all? { |k| columns_hash.key?(k) }

        statement = cached_find_by_statement(keys) { |params|
          wheres = keys.index_with { params.bind }
          where(wheres).limit(1)
        }

        begin
          statement.execute(values, connection)&.first
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
      #
      #   class Post < ActiveRecord::Base
      #     scope :published_and_commented, -> { published.and(arel_table[:comments_count].gt(0)) }
      #   end
      def arel_table # :nodoc:
        @arel_table ||= Arel::Table.new(table_name, type_caster: type_caster)
      end

      def arel_attribute(name, table = arel_table) # :nodoc:
        name = name.to_s
        name = attribute_aliases[name] || name
        table[name]
      end

      def predicate_builder # :nodoc:
        @predicate_builder ||= PredicateBuilder.new(table_metadata)
      end

      def type_caster # :nodoc:
        TypeCaster::Map.new(self)
      end

      def _internal? # :nodoc:
        false
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
            relation.create_with!(inheritance_column.to_s => sti_name)
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

    # Returns +true+ if the record is read only. Records loaded through joins with piggy-back
    # attributes will be marked as read only since they cannot be saved.
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
    #   user.strict_loading!
    #   user.comments.to_a
    #   => ActiveRecord::StrictLoadingViolationError
    def strict_loading!
      @strict_loading = true
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
            attr = _read_attribute(name)
            value = if attr.nil?
              attr.inspect
            else
              attr = format_for_inspect(attr)
              inspection_filter.filter_param(name, attr)
            end
            "#{name}: #{value}"
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
      Hash[methods.flatten.map! { |method| [method, public_send(method)] }].with_indifferent_access
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
