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
      class_attribute :logger, instance_writer: false

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
      # Force enumeration of all columns in SELECT statements.
      # e.g. <tt>SELECT first_name, last_name FROM ...</tt> instead of <tt>SELECT * FROM ...</tt>
      # This avoids +PreparedStatementCacheExpired+ errors when a column is added
      # to the database while the app is running.
      class_attribute :enumerate_columns_in_select_statements, instance_accessor: false, default: false

      class_attribute :belongs_to_required_by_default, instance_accessor: false

      class_attribute :strict_loading_by_default, instance_accessor: false, default: false

      class_attribute :has_many_inversing, instance_accessor: false, default: false

      class_attribute :default_connection_handler, instance_writer: false

      class_attribute :default_role, instance_writer: false

      class_attribute :default_shard, instance_writer: false

      class_attribute :shard_selector, instance_accessor: false, default: nil

      def self.application_record_class? # :nodoc:
        if ActiveRecord.application_record_class
          self == ActiveRecord.application_record_class
        else
          if defined?(ApplicationRecord) && self == ApplicationRecord
            true
          end
        end
      end

      self.filter_attributes = []

      def self.connection_handler
        ActiveSupport::IsolatedExecutionState[:active_record_connection_handler] || default_connection_handler
      end

      def self.connection_handler=(handler)
        ActiveSupport::IsolatedExecutionState[:active_record_connection_handler] = handler
      end

      def self.connection_handlers
        if ActiveRecord.legacy_connection_handling
        else
          raise NotImplementedError, "The new connection handling does not support accessing multiple connection handlers."
        end

        @@connection_handlers ||= {}
      end

      def self.connection_handlers=(handlers)
        if ActiveRecord.legacy_connection_handling
          ActiveSupport::Deprecation.warn(<<~MSG)
            Using legacy connection handling is deprecated. Please set
            `legacy_connection_handling` to `false` in your application.

            The new connection handling does not support `connection_handlers`
            getter and setter.

            Read more about how to migrate at: https://guides.rubyonrails.org/active_record_multiple_databases.html#migrate-to-the-new-connection-handling
          MSG
        else
          raise NotImplementedError, "The new connection handling does not support multiple connection handlers."
        end

        @@connection_handlers = handlers
      end

      def self.asynchronous_queries_session # :nodoc:
        asynchronous_queries_tracker.current_session
      end

      def self.asynchronous_queries_tracker # :nodoc:
        ActiveSupport::IsolatedExecutionState[:active_record_asynchronous_queries_tracker] ||= \
          AsynchronousQueriesTracker.new
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
        if ActiveRecord.legacy_connection_handling
          connection_handlers.key(connection_handler) || default_role
        else
          connected_to_stack.reverse_each do |hash|
            return hash[:role] if hash[:role] && hash[:klasses].include?(Base)
            return hash[:role] if hash[:role] && hash[:klasses].include?(connection_class_for_self)
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
          return hash[:shard] if hash[:shard] && hash[:klasses].include?(connection_class_for_self)
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
        if ActiveRecord.legacy_connection_handling
          connection_handler.prevent_writes
        else
          connected_to_stack.reverse_each do |hash|
            return hash[:prevent_writes] if !hash[:prevent_writes].nil? && hash[:klasses].include?(Base)
            return hash[:prevent_writes] if !hash[:prevent_writes].nil? && hash[:klasses].include?(connection_class_for_self)
          end

          false
        end
      end

      def self.connected_to_stack # :nodoc:
        if connected_to_stack = ActiveSupport::IsolatedExecutionState[:active_record_connected_to_stack]
          connected_to_stack
        else
          connected_to_stack = Concurrent::Array.new
          ActiveSupport::IsolatedExecutionState[:active_record_connected_to_stack] = connected_to_stack
          connected_to_stack
        end
      end

      def self.connection_class=(b) # :nodoc:
        @connection_class = b
      end

      def self.connection_class # :nodoc:
        @connection_class ||= false
      end

      def self.connection_class? # :nodoc:
        self.connection_class
      end

      def self.connection_class_for_self # :nodoc:
        klass = self

        until klass == Base
          break if klass.connection_class?
          klass = klass.superclass
        end

        klass
      end

      self.default_connection_handler = ConnectionAdapters::ConnectionHandler.new
      self.default_role = ActiveRecord.writing_role
      self.default_shard = :default

      def self.strict_loading_violation!(owner:, reflection:) # :nodoc:
        case ActiveRecord.action_on_strict_loading_violation
        when :raise
          message = reflection.strict_loading_violation_message(owner)
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
        find_by(*args) || where(*args).raise_record_not_found_exception!
      end

      %w(
        reading_role writing_role legacy_connection_handling default_timezone index_nested_attribute_errors
        verbose_query_logs queues warn_on_records_fetched_greater_than maintain_test_schema
        application_record_class action_on_strict_loading_violation schema_format error_on_ignored_order
        timestamped_migrations dump_schema_after_migration dump_schemas suppress_multiple_database_warning
      ).each do |attr|
        module_eval(<<~RUBY, __FILE__, __LINE__ + 1)
          def #{attr}
            ActiveSupport::Deprecation.warn(<<~MSG)
              ActiveRecord::Base.#{attr} is deprecated and will be removed in Rails 7.1.
              Use `ActiveRecord.#{attr}` instead.
            MSG
            ActiveRecord.#{attr}
          end

          def #{attr}=(value)
            ActiveSupport::Deprecation.warn(<<~MSG)
              ActiveRecord::Base.#{attr}= is deprecated and will be removed in Rails 7.1.
              Use `ActiveRecord.#{attr}=` instead.
            MSG
            ActiveRecord.#{attr} = value
          end
        RUBY
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
      def filter_attributes=(filter_attributes)
        @inspection_filter = nil
        @filter_attributes = filter_attributes
      end

      def inspection_filter # :nodoc:
        if defined?(@filter_attributes)
          @inspection_filter ||= begin
            mask = InspectionMask.new(ActiveSupport::ParameterFilter::FILTERED)
            ActiveSupport::ParameterFilter.new(@filter_attributes, mask: mask)
          end
        else
          superclass.inspection_filter
        end
      end

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

      # Override the default class equality method to provide support for decorated models.
      def ===(object) # :nodoc:
        object.is_a?(self)
      end

      # Returns an instance of <tt>Arel::Table</tt> loaded with the current table name.
      def arel_table # :nodoc:
        @arel_table ||= Arel::Table.new(table_name, klass: self)
      end

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
      coder = LegacyYamlAdapter.convert(coder)
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
      id = self.id

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
    # === Parameters:
    #
    # * value - Boolean specifying whether to enable or disable strict loading.
    # * mode - Symbol specifying strict loading mode. Defaults to :all. Using
    #          :n_plus_one_only mode will only raise an error if an association
    #          that will lead to an n plus one query is lazily loaded.
    #
    # === Example:
    #
    #   user = User.first
    #   user.strict_loading!(false) # => false
    #   user.comments
    #   => #<ActiveRecord::Associations::CollectionProxy>
    def strict_loading!(value = true, mode: :all)
      unless [:all, :n_plus_one_only].include?(mode)
        raise ArgumentError, "The :mode option must be one of [:all, :n_plus_one_only]."
      end

      @strict_loading_mode = mode
      @strict_loading = value
    end

    attr_reader :strict_loading_mode

    # Returns +true+ if the record uses strict_loading with +:n_plus_one_only+ mode enabled.
    def strict_loading_n_plus_one_only?
      @strict_loading_mode == :n_plus_one_only
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
        self.class.attribute_names.filter_map do |name|
          if _has_attribute?(name)
            "#{name}: #{attribute_for_inspect(name)}"
          end
        end.join(", ")
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
        @readonly                 = false
        @previously_new_record    = false
        @destroyed                = false
        @marked_for_destruction   = false
        @destroyed_by_association = nil
        @_start_transaction_state = nil

        klass = self.class

        @primary_key         = klass.primary_key
        @strict_loading      = klass.strict_loading_by_default
        @strict_loading_mode = :all

        klass.define_attribute_methods
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
        self.class.inspection_filter
      end
  end
end
