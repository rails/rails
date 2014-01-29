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

      ##
      # :singleton-method:
      # Disable implicit join references. This feature was deprecated with Rails 4.
      # If you don't make use of implicit references but still see deprecation warnings
      # you can disable the feature entirely. This will be the default with Rails 4.1.
      mattr_accessor :disable_implicit_join_references, instance_writer: false
      self.disable_implicit_join_references = false

      class_attribute :default_connection_handler, instance_writer: false

      def self.connection_handler
        ActiveRecord::RuntimeRegistry.connection_handler || default_connection_handler
      end

      def self.connection_handler=(handler)
        ActiveRecord::RuntimeRegistry.connection_handler = handler
      end

      self.default_connection_handler = ConnectionAdapters::ConnectionHandler.new
    end

    module ClassMethods
      def initialize_generated_modules
        super

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
    #   User.new(first_name: 'Jamie')
    def initialize(attributes = nil, options = {})
      defaults = self.class.column_defaults.dup
      defaults.each { |k, v| defaults[k] = v.dup if v.duplicable? }

      @attributes   = self.class.initialize_attributes(defaults)
      @column_types_override = nil
      @column_types = self.class.column_types

      init_internals
      init_changed_attributes
      ensure_proper_type
      populate_with_current_scope_attributes

      # +options+ argument is only needed to make protected_attributes gem easier to hook.
      # Remove it when we drop support to this gem.
      init_attributes(attributes, options) if attributes

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
      @column_types_override = coder['column_types']
      @column_types = self.class.column_types

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
      init_changed_attributes

      @aggregation_cache = {}
      @association_cache = {}
      @attributes_cache  = {}

      @new_record  = true

      ensure_proper_type
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
      coder['attributes'] = attributes_for_coder
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
      ActiveSupport::Deprecation.warn("#connection is deprecated in favour of accessing it via the class")
      self.class.connection
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

    # Returns a hash of the given methods with their names as keys and returned values as values.
    def slice(*methods)
      Hash[methods.map { |method| [method, public_send(method)] }].with_indifferent_access
    end

    def set_transaction_state(state) # :nodoc:
      @transaction_state = state
    end

    def has_transactional_callbacks? # :nodoc:
      !_rollback_callbacks.empty? || !_commit_callbacks.empty? || !_create_callbacks.empty?
    end

    # Required to deserialize Syck properly.
    if YAML.const_defined?(:ENGINE) && YAML::ENGINE.syck?
      ActiveSupport::Deprecation.warn(
        "Syck is deprecated and support for serialization has been removed." \
        " ActiveRecord::Core#yaml_initialize will be removed in 4.1 which will break deserialization support with Syck."
      )
      def yaml_initialize(tag, coder) # :nodoc:
        init_with(coder)
      end
    end

    private

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
      pk = self.class.primary_key
      @attributes[pk] = nil unless @attributes.key?(pk)

      @aggregation_cache        = {}
      @association_cache        = {}
      @attributes_cache         = {}
      @previously_changed       = {}
      @changed_attributes       = {}
      @readonly                 = false
      @destroyed                = false
      @marked_for_destruction   = false
      @destroyed_by_association = nil
      @new_record               = true
      @txn                      = nil
      @_start_transaction_state = {}
      @transaction_state        = nil
      @reflects_state           = [false]
    end

    def init_changed_attributes
      # Intentionally avoid using #column_defaults since overridden defaults (as is done in
      # optimistic locking) won't get written unless they get marked as changed
      self.class.columns.each do |c|
        attr, orig_value = c.name, c.default
        @changed_attributes[attr] = orig_value if _field_changed?(attr, orig_value, @attributes[attr])
      end
    end

    # This method is needed to make protected_attributes gem easier to hook.
    # Remove it when we drop support to this gem.
    def init_attributes(attributes, options)
      assign_attributes(attributes)
    end
  end
end
