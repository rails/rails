require 'thread'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/object/duplicable'
require 'active_support/core_ext/string/filters'

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
      def self.configurations=(config)
        @@configurations = ActiveRecord::ConnectionHandling::MergeAndResolveDefaultUrlConfig.new(config).resolve
      end
      self.configurations = {}

      # Returns fully resolved configurations hash
      def self.configurations
        @@configurations
      end

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

      ##
      # :singleton-method:
      # Specify whether schema dump should happen at the end of the
      # db:migrate rake task. This is true by default, which is useful for the
      # development environment. This should ideally be false in the production
      # environment where dumping schema is rarely needed.
      mattr_accessor :dump_schema_after_migration, instance_writer: false
      self.dump_schema_after_migration = true

      mattr_accessor :maintain_test_schema, instance_accessor: false

      def self.disable_implicit_join_references=(value)
        ActiveSupport::Deprecation.warn(<<-MSG.squish)
          Implicit join references were removed with Rails 4.1.
          Make sure to remove this configuration because it does nothing.
        MSG
      end

      class_attribute :default_connection_handler, instance_writer: false
      class_attribute :find_by_statement_cache

      def self.connection_handler
        ActiveRecord::RuntimeRegistry.connection_handler || default_connection_handler
      end

      def self.connection_handler=(handler)
        ActiveRecord::RuntimeRegistry.connection_handler = handler
      end

      self.default_connection_handler = ConnectionAdapters::ConnectionHandler.new
    end

    module ClassMethods
      def allocate
        define_attribute_methods
        super
      end

      def initialize_find_by_cache # :nodoc:
        self.find_by_statement_cache = {}.extend(Mutex_m)
      end

      def inherited(child_class) # :nodoc:
        child_class.initialize_find_by_cache
        super
      end

      def find(*ids) # :nodoc:
        # We don't have cache keys for this stuff yet
        return super unless ids.length == 1
        # Allow symbols to super to maintain compatibility for deprecated finders until Rails 5
        return super if ids.first.kind_of?(Symbol)
        return super if block_given? ||
                        primary_key.nil? ||
                        default_scopes.any? ||
                        current_scope ||
                        columns_hash.include?(inheritance_column) ||
                        ids.first.kind_of?(Array)

        id  = ids.first
        if ActiveRecord::Base === id
          id = id.id
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
            You are passing an instance of ActiveRecord::Base to `find`.
            Please pass the id of the object by calling `.id`
          MSG
        end
        key = primary_key

        s = find_by_statement_cache[key] || find_by_statement_cache.synchronize {
          find_by_statement_cache[key] ||= StatementCache.create(connection) { |params|
            where(key => params.bind).limit(1)
          }
        }
        record = s.execute([id], self, connection).first
        unless record
          raise RecordNotFound, "Couldn't find #{name} with '#{primary_key}'=#{id}"
        end
        record
      rescue RangeError
        raise RecordNotFound, "Couldn't find #{name} with an out of range value for '#{primary_key}'"
      end

      def find_by(*args) # :nodoc:
        return super if current_scope || !(Hash === args.first) || reflect_on_all_aggregations.any?
        return super if default_scopes.any?

        hash = args.first

        return super if hash.values.any? { |v|
          v.nil? || Array === v || Hash === v
        }

        # We can't cache Post.find_by(author: david) ...yet
        return super unless hash.keys.all? { |k| columns_hash.has_key?(k.to_s) }

        key  = hash.keys

        klass = self
        s = find_by_statement_cache[key] || find_by_statement_cache.synchronize {
          find_by_statement_cache[key] ||= StatementCache.create(connection) { |params|
            wheres = key.each_with_object({}) { |param,o|
              o[param] = params.bind
            }
            klass.where(wheres).limit(1)
          }
        }
        begin
          s.execute(hash.values, self, connection).first
        rescue TypeError => e
          raise ActiveRecord::StatementInvalid.new(e.message, e)
        rescue RangeError
          nil
        end
      end

      def find_by!(*args) # :nodoc:
        find_by(*args) or raise RecordNotFound.new("Couldn't find #{name}")
      end

      def initialize_generated_modules # :nodoc:
        generated_association_methods
      end

      def generated_association_methods
        @generated_association_methods ||= begin
          mod = const_set(:GeneratedAssociationMethods, Module.new)
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
        elsif !connected?
          "#{super} (call '#{super}.connection' to establish a connection)"
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
      #     scope :published_and_commented, -> { published.and(self.arel_table[:comments_count].gt(0)) }
      #   end
      def arel_table # :nodoc:
        @arel_table ||= Arel::Table.new(table_name, arel_engine)
      end

      # Returns the Arel engine.
      def arel_engine # :nodoc:
        @arel_engine ||=
          if Base == self || connection_handler.retrieve_connection_pool(self)
            self
          else
            superclass.arel_engine
          end
      end

      private

      def relation #:nodoc:
        relation = Relation.create(self, arel_table)

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
    #   User.new(first_name: 'Jamie')
    def initialize(attributes = nil, options = {})
      @attributes = self.class._default_attributes.dup
      self.class.define_attribute_methods

      init_internals
      initialize_internals_callback

      # +options+ argument is only needed to make protected_attributes gem easier to hook.
      # Remove it when we drop support to this gem.
      init_attributes(attributes, options) if attributes

      yield self if block_given?
      _run_initialize_callbacks
    end

    # Initialize an empty model object from +coder+. +coder+ should be
    # the result of previously encoding an Active Record model, using
    # `encode_with`
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
    def init_with(coder)
      @attributes = coder['attributes']

      init_internals

      @new_record = coder['new_record']

      self.class.define_attribute_methods

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
      @attributes = @attributes.dup
      @attributes.reset(self.class.primary_key)

      _run_initialize_callbacks

      @aggregation_cache = {}
      @association_cache = {}

      @new_record  = true
      @destroyed   = false

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
      # FIXME: Remove this when we better serialize attributes
      coder['raw_attributes'] = attributes_before_type_cast
      coder['attributes'] = @attributes
      coder['new_record'] = new_record?
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
        id.hash
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
        self.to_key <=> other_object.to_key
      else
        super
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

    def connection_handler
      self.class.connection_handler
    end

    # Returns the contents of the record as a nicely formatted string.
    def inspect
      # We check defined?(@attributes) not to issue warnings if the object is
      # allocated but not initialized.
      inspection = if defined?(@attributes) && @attributes
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

    # Takes a PP and prettily prints this record to it, allowing you to get a nice result from `pp record`
    # when pp is required.
    def pretty_print(pp)
      return super if custom_inspect_method_defined?
      pp.object_address_group(self) do
        if defined?(@attributes) && @attributes
          column_names = self.class.column_names.select { |name| has_attribute?(name) || new_record? }
          pp.seplist(column_names, proc { pp.text ',' }) do |column_name|
            column_value = read_attribute(column_name)
            pp.breakable ' '
            pp.group(1) do
              pp.text column_name
              pp.text ':'
              pp.breakable
              pp.pp column_value
            end
          end
        else
          pp.breakable ' '
          pp.text 'not initialized'
        end
      end
    end

    # Returns a hash of the given methods with their names as keys and returned values as values.
    def slice(*methods)
      Hash[methods.map! { |method| [method, public_send(method)] }].with_indifferent_access
    end

    private

    def set_transaction_state(state) # :nodoc:
      @transaction_state = state
    end

    def has_transactional_callbacks? # :nodoc:
      !_rollback_callbacks.empty? || !_commit_callbacks.empty?
    end

    # Updates the attributes on this particular ActiveRecord object so that
    # if it is associated with a transaction, then the state of the AR object
    # will be updated to reflect the current state of the transaction
    #
    # The @transaction_state variable stores the states of the associated
    # transaction. This relies on the fact that a transaction can only be in
    # one rollback or commit (otherwise a list of states would be required)
    # Each AR object inside of a transaction carries that transaction's
    # TransactionState.
    #
    # This method checks to see if the ActiveRecord object's state reflects
    # the TransactionState, and rolls back or commits the ActiveRecord object
    # as appropriate.
    #
    # Since ActiveRecord objects can be inside multiple transactions, this
    # method recursively goes through the parent of the TransactionState and
    # checks if the ActiveRecord object reflects the state of the object.
    def sync_with_transaction_state
      update_attributes_from_transaction_state(@transaction_state, 0)
    end

    def update_attributes_from_transaction_state(transaction_state, depth)
      @reflects_state = [false] if depth == 0

      if transaction_state && transaction_state.finalized? && !has_transactional_callbacks?
        unless @reflects_state[depth]
          restore_transaction_record_state if transaction_state.rolledback?
          clear_transaction_record_state
          @reflects_state[depth] = true
        end

        if transaction_state.parent && !@reflects_state[depth+1]
          update_attributes_from_transaction_state(transaction_state.parent, depth+1)
        end
      end
    end

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
      @aggregation_cache        = {}
      @association_cache        = {}
      @readonly                 = false
      @destroyed                = false
      @marked_for_destruction   = false
      @destroyed_by_association = nil
      @new_record               = true
      @txn                      = nil
      @_start_transaction_state = {}
      @transaction_state        = nil
    end

    def initialize_internals_callback
    end

    # This method is needed to make protected_attributes gem easier to hook.
    # Remove it when we drop support to this gem.
    def init_attributes(attributes, options)
      assign_attributes(attributes)
    end

    def thaw
      if frozen?
        @attributes = @attributes.dup
      end
    end

    def custom_inspect_method_defined?
      self.class.instance_method(:inspect).owner != ActiveRecord::Base.instance_method(:inspect).owner
    end
  end
end
