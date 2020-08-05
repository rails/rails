# frozen_string_literal: true

require "monitor"

module ActiveRecord
  module ModelSchema
    extend ActiveSupport::Concern

    ##
    # :singleton-method: primary_key_prefix_type
    # :call-seq: primary_key_prefix_type
    #
    # The prefix type that will be prepended to every primary key column name.
    # The options are +:table_name+ and +:table_name_with_underscore+. If the first is specified,
    # the Product class will look for "productid" instead of "id" as the primary column. If the
    # latter is specified, the Product class will look for "product_id" instead of "id". Remember
    # that this is a global setting for all Active Records.

    ##
    # :singleton-method: primary_key_prefix_type=
    # :call-seq: primary_key_prefix_type=(prefix_type)
    #
    # Sets the prefix type that will be prepended to every primary key column name.
    # The options are +:table_name+ and +:table_name_with_underscore+. If the first is specified,
    # the Product class will look for "productid" instead of "id" as the primary column. If the
    # latter is specified, the Product class will look for "product_id" instead of "id". Remember
    # that this is a global setting for all Active Records.

    ##
    # :singleton-method: table_name_prefix
    # :call-seq: table_name_prefix
    #
    # The prefix string to prepend to every table name.

    ##
    # :singleton-method: table_name_prefix=
    # :call-seq: table_name_prefix=(prefix)
    #
    # Sets the prefix string to prepend to every table name. So if set to "basecamp_", all table
    # names will be named like "basecamp_projects", "basecamp_people", etc. This is a convenient
    # way of creating a namespace for tables in a shared database. By default, the prefix is the
    # empty string.
    #
    # If you are organising your models within modules you can add a prefix to the models within
    # a namespace by defining a singleton method in the parent module called table_name_prefix which
    # returns your chosen prefix.

    ##
    # :singleton-method: table_name_suffix
    # :call-seq: table_name_suffix
    #
    # The suffix string to append to every table name.

    ##
    # :singleton-method: table_name_suffix=
    # :call-seq: table_name_suffix=(suffix)
    #
    # Works like +table_name_prefix=+, but appends instead of prepends (set to "_basecamp" gives "projects_basecamp",
    # "people_basecamp"). By default, the suffix is the empty string.
    #
    # If you are organising your models within modules, you can add a suffix to the models within
    # a namespace by defining a singleton method in the parent module called table_name_suffix which
    # returns your chosen suffix.

    ##
    # :singleton-method: schema_migrations_table_name
    # :call-seq: schema_migrations_table_name
    #
    # The name of the schema migrations table. By default, the value is <tt>"schema_migrations"</tt>.

    ##
    # :singleton-method: schema_migrations_table_name=
    # :call-seq: schema_migrations_table_name=(table_name)
    #
    # Sets the name of the schema migrations table.

    ##
    # :singleton-method: internal_metadata_table_name
    # :call-seq: internal_metadata_table_name
    #
    # The name of the internal metadata table. By default, the value is <tt>"ar_internal_metadata"</tt>.

    ##
    # :singleton-method: internal_metadata_table_name=
    # :call-seq: internal_metadata_table_name=(table_name)
    #
    # Sets the name of the internal metadata table.

    ##
    # :singleton-method: pluralize_table_names
    # :call-seq: pluralize_table_names
    #
    # Indicates whether table names should be the pluralized versions of the corresponding class names.
    # If true, the default table name for a Product class will be "products". If false, it would just be "product".
    # See table_name for the full rules on table/class naming. This is true, by default.

    ##
    # :singleton-method: pluralize_table_names=
    # :call-seq: pluralize_table_names=(value)
    #
    # Set whether table names should be the pluralized versions of the corresponding class names.
    # If true, the default table name for a Product class will be "products". If false, it would just be "product".
    # See table_name for the full rules on table/class naming. This is true, by default.

    ##
    # :singleton-method: implicit_order_column
    # :call-seq: implicit_order_column
    #
    # The name of the column records are ordered by if no explicit order clause
    # is used during an ordered finder call. If not set the primary key is used.

    ##
    # :singleton-method: implicit_order_column=
    # :call-seq: implicit_order_column=(column_name)
    #
    # Sets the column to sort records by when no explicit order clause is used
    # during an ordered finder call. Useful when the primary key is not an
    # auto-incrementing integer, for example when it's a UUID. Records are subsorted
    # by the primary key if it exists to ensure deterministic results.

    ##
    # :singleton-method: immutable_strings_by_default=
    # :call-seq: immutable_strings_by_default=(bool)
    #
    # Determines whether columns should infer their type as `:string` or
    # `:immutable_string`. This setting does not affect the behavior of
    # `attribute :foo, :string`. Defaults to false.

    included do
      mattr_accessor :primary_key_prefix_type, instance_writer: false

      class_attribute :table_name_prefix, instance_writer: false, default: ""
      class_attribute :table_name_suffix, instance_writer: false, default: ""
      class_attribute :schema_migrations_table_name, instance_accessor: false, default: "schema_migrations"
      class_attribute :internal_metadata_table_name, instance_accessor: false, default: "ar_internal_metadata"
      class_attribute :pluralize_table_names, instance_writer: false, default: true
      class_attribute :implicit_order_column, instance_accessor: false
      class_attribute :immutable_strings_by_default, instance_accessor: false

      self.protected_environments = ["production"]
      self.inheritance_column = "type"
      self.ignored_columns = [].freeze

      delegate :type_for_attribute, :column_for_attribute, to: :class

      initialize_load_schema_monitor
    end

    # Derives the join table name for +first_table+ and +second_table+. The
    # table names appear in alphabetical order. A common prefix is removed
    # (useful for namespaced models like Music::Artist and Music::Record):
    #
    #   artists, records => artists_records
    #   records, artists => artists_records
    #   music_artists, music_records => music_artists_records
    def self.derive_join_table_name(first_table, second_table) # :nodoc:
      [first_table.to_s, second_table.to_s].sort.join("\0").gsub(/^(.*_)(.+)\0\1(.+)/, '\1\2_\3').tr("\0", "_")
    end

    module ClassMethods
      # Guesses the table name (in forced lower-case) based on the name of the class in the
      # inheritance hierarchy descending directly from ActiveRecord::Base. So if the hierarchy
      # looks like: Reply < Message < ActiveRecord::Base, then Message is used
      # to guess the table name even when called on Reply. The rules used to do the guess
      # are handled by the Inflector class in Active Support, which knows almost all common
      # English inflections. You can add new inflections in config/initializers/inflections.rb.
      #
      # Nested classes are given table names prefixed by the singular form of
      # the parent's table name. Enclosing modules are not considered.
      #
      # ==== Examples
      #
      #   class Invoice < ActiveRecord::Base
      #   end
      #
      #   file                  class               table_name
      #   invoice.rb            Invoice             invoices
      #
      #   class Invoice < ActiveRecord::Base
      #     class Lineitem < ActiveRecord::Base
      #     end
      #   end
      #
      #   file                  class               table_name
      #   invoice.rb            Invoice::Lineitem   invoice_lineitems
      #
      #   module Invoice
      #     class Lineitem < ActiveRecord::Base
      #     end
      #   end
      #
      #   file                  class               table_name
      #   invoice/lineitem.rb   Invoice::Lineitem   lineitems
      #
      # Additionally, the class-level +table_name_prefix+ is prepended and the
      # +table_name_suffix+ is appended. So if you have "myapp_" as a prefix,
      # the table name guess for an Invoice class becomes "myapp_invoices".
      # Invoice::Lineitem becomes "myapp_invoice_lineitems".
      #
      # You can also set your own table name explicitly:
      #
      #   class Mouse < ActiveRecord::Base
      #     self.table_name = "mice"
      #   end
      def table_name
        reset_table_name unless defined?(@table_name)
        @table_name
      end

      # Sets the table name explicitly. Example:
      #
      #   class Project < ActiveRecord::Base
      #     self.table_name = "project"
      #   end
      def table_name=(value)
        value = value && value.to_s

        if defined?(@table_name)
          return if value == @table_name
          reset_column_information if connected?
        end

        @table_name        = value
        @quoted_table_name = nil
        @arel_table        = nil
        @sequence_name     = nil unless defined?(@explicit_sequence_name) && @explicit_sequence_name
        @predicate_builder = nil
      end

      # Returns a quoted version of the table name, used to construct SQL statements.
      def quoted_table_name
        @quoted_table_name ||= connection.quote_table_name(table_name)
      end

      # Computes the table name, (re)sets it internally, and returns it.
      def reset_table_name #:nodoc:
        self.table_name = if abstract_class?
          superclass == Base ? nil : superclass.table_name
        elsif superclass.abstract_class?
          superclass.table_name || compute_table_name
        else
          compute_table_name
        end
      end

      def full_table_name_prefix #:nodoc:
        (module_parents.detect { |p| p.respond_to?(:table_name_prefix) } || self).table_name_prefix
      end

      def full_table_name_suffix #:nodoc:
        (module_parents.detect { |p| p.respond_to?(:table_name_suffix) } || self).table_name_suffix
      end

      # The array of names of environments where destructive actions should be prohibited. By default,
      # the value is <tt>["production"]</tt>.
      def protected_environments
        if defined?(@protected_environments)
          @protected_environments
        else
          superclass.protected_environments
        end
      end

      # Sets an array of names of environments where destructive actions should be prohibited.
      def protected_environments=(environments)
        @protected_environments = environments.map(&:to_s)
      end

      # Defines the name of the table column which will store the class name on single-table
      # inheritance situations.
      #
      # The default inheritance column name is +type+, which means it's a
      # reserved word inside Active Record. To be able to use single-table
      # inheritance with another column name, or to use the column +type+ in
      # your own model for something else, you can set +inheritance_column+:
      #
      #     self.inheritance_column = 'zoink'
      def inheritance_column
        (@inheritance_column ||= nil) || superclass.inheritance_column
      end

      # Sets the value of inheritance_column
      def inheritance_column=(value)
        @inheritance_column = value.to_s
        @explicit_inheritance_column = true
      end

      # The list of columns names the model should ignore. Ignored columns won't have attribute
      # accessors defined, and won't be referenced in SQL queries.
      def ignored_columns
        if defined?(@ignored_columns)
          @ignored_columns
        else
          superclass.ignored_columns
        end
      end

      # Sets the columns names the model should ignore. Ignored columns won't have attribute
      # accessors defined, and won't be referenced in SQL queries.
      def ignored_columns=(columns)
        reload_schema_from_cache
        @ignored_columns = columns.map(&:to_s).freeze
      end

      def sequence_name
        if base_class?
          @sequence_name ||= reset_sequence_name
        else
          (@sequence_name ||= nil) || base_class.sequence_name
        end
      end

      def reset_sequence_name #:nodoc:
        @explicit_sequence_name = false
        @sequence_name          = connection.default_sequence_name(table_name, primary_key)
      end

      # Sets the name of the sequence to use when generating ids to the given
      # value, or (if the value is +nil+ or +false+) to the value returned by the
      # given block. This is required for Oracle and is useful for any
      # database which relies on sequences for primary key generation.
      #
      # If a sequence name is not explicitly set when using Oracle,
      # it will default to the commonly used pattern of: #{table_name}_seq
      #
      # If a sequence name is not explicitly set when using PostgreSQL, it
      # will discover the sequence corresponding to your primary key for you.
      #
      #   class Project < ActiveRecord::Base
      #     self.sequence_name = "projectseq"   # default would have been "project_seq"
      #   end
      def sequence_name=(value)
        @sequence_name          = value.to_s
        @explicit_sequence_name = true
      end

      # Determines if the primary key values should be selected from their
      # corresponding sequence before the insert statement.
      def prefetch_primary_key?
        connection.prefetch_primary_key?(table_name)
      end

      # Returns the next value that will be used as the primary key on
      # an insert statement.
      def next_sequence_value
        connection.next_sequence_value(sequence_name)
      end

      # Indicates whether the table associated with this class exists
      def table_exists?
        connection.schema_cache.data_source_exists?(table_name)
      end

      def attributes_builder # :nodoc:
        unless defined?(@attributes_builder) && @attributes_builder
          defaults = _default_attributes.except(*(column_names - [primary_key]))
          @attributes_builder = ActiveModel::AttributeSet::Builder.new(attribute_types, defaults)
        end
        @attributes_builder
      end

      def columns_hash # :nodoc:
        load_schema
        @columns_hash
      end

      def columns
        load_schema
        @columns ||= columns_hash.values.freeze
      end

      def attribute_types # :nodoc:
        load_schema
        @attribute_types ||= Hash.new(Type.default_value)
      end

      def yaml_encoder # :nodoc:
        @yaml_encoder ||= ActiveModel::AttributeSet::YAMLEncoder.new(attribute_types)
      end

      # Returns the type of the attribute with the given name, after applying
      # all modifiers. This method is the only valid source of information for
      # anything related to the types of a model's attributes. This method will
      # access the database and load the model's schema if it is required.
      #
      # The return value of this method will implement the interface described
      # by ActiveModel::Type::Value (though the object itself may not subclass
      # it).
      #
      # +attr_name+ The name of the attribute to retrieve the type for. Must be
      # a string or a symbol.
      def type_for_attribute(attr_name, &block)
        attr_name = attr_name.to_s
        attr_name = attribute_aliases[attr_name] || attr_name

        if block
          attribute_types.fetch(attr_name, &block)
        else
          attribute_types[attr_name]
        end
      end

      # Returns the column object for the named attribute.
      # Returns an +ActiveRecord::ConnectionAdapters::NullColumn+ if the
      # named attribute does not exist.
      #
      #   class Person < ActiveRecord::Base
      #   end
      #
      #   person = Person.new
      #   person.column_for_attribute(:name) # the result depends on the ConnectionAdapter
      #   # => #<ActiveRecord::ConnectionAdapters::Column:0x007ff4ab083980 @name="name", @sql_type="varchar(255)", @null=true, ...>
      #
      #   person.column_for_attribute(:nothing)
      #   # => #<ActiveRecord::ConnectionAdapters::NullColumn:0xXXX @name=nil, @sql_type=nil, @cast_type=#<Type::Value>, ...>
      def column_for_attribute(name)
        name = name.to_s
        columns_hash.fetch(name) do
          ConnectionAdapters::NullColumn.new(name)
        end
      end

      # Returns a hash where the keys are column names and the values are
      # default values when instantiating the Active Record object for this table.
      def column_defaults
        load_schema
        @column_defaults ||= _default_attributes.deep_dup.to_hash.freeze
      end

      def _default_attributes # :nodoc:
        load_schema
        @default_attributes ||= ActiveModel::AttributeSet.new({})
      end

      # Returns an array of column names as strings.
      def column_names
        @column_names ||= columns.map(&:name).freeze
      end

      def symbol_column_to_string(name_symbol) # :nodoc:
        @symbol_column_to_string_name_hash ||= column_names.index_by(&:to_sym)
        @symbol_column_to_string_name_hash[name_symbol]
      end

      # Returns an array of column objects where the primary id, all columns ending in "_id" or "_count",
      # and columns used for single table inheritance have been removed.
      def content_columns
        @content_columns ||= columns.reject do |c|
          c.name == primary_key ||
          c.name == inheritance_column ||
          c.name.end_with?("_id", "_count")
        end.freeze
      end

      # Resets all the cached information about columns, which will cause them
      # to be reloaded on the next request.
      #
      # The most common usage pattern for this method is probably in a migration,
      # when just after creating a table you want to populate it with some default
      # values, eg:
      #
      #  class CreateJobLevels < ActiveRecord::Migration[6.0]
      #    def up
      #      create_table :job_levels do |t|
      #        t.integer :id
      #        t.string :name
      #
      #        t.timestamps
      #      end
      #
      #      JobLevel.reset_column_information
      #      %w{assistant executive manager director}.each do |type|
      #        JobLevel.create(name: type)
      #      end
      #    end
      #
      #    def down
      #      drop_table :job_levels
      #    end
      #  end
      def reset_column_information
        connection.clear_cache!
        ([self] + descendants).each(&:undefine_attribute_methods)
        connection.schema_cache.clear_data_source_cache!(table_name)

        reload_schema_from_cache
        initialize_find_by_cache
      end

      protected
        def initialize_load_schema_monitor
          @load_schema_monitor = Monitor.new
        end

      private
        def inherited(child_class)
          super
          child_class.initialize_load_schema_monitor
        end

        def schema_loaded?
          defined?(@schema_loaded) && @schema_loaded
        end

        def load_schema
          return if schema_loaded?
          @load_schema_monitor.synchronize do
            return if defined?(@columns_hash) && @columns_hash

            load_schema!

            @schema_loaded = true
          rescue
            reload_schema_from_cache # If the schema loading failed half way through, we must reset the state.
            raise
          end
        end

        def load_schema!
          unless table_name
            raise ActiveRecord::TableNotSpecified, "#{self} has no table configured. Set one with #{self}.table_name="
          end

          columns_hash = connection.schema_cache.columns_hash(table_name)
          columns_hash = columns_hash.except(*ignored_columns) unless ignored_columns.empty?
          @columns_hash = columns_hash.freeze
          @columns_hash.each do |name, column|
            type = connection.lookup_cast_type_from_column(column)
            type = _convert_type_from_options(type)
            define_attribute(
              name,
              type,
              default: column.default,
              user_provided_default: false
            )
          end
        end

        def reload_schema_from_cache
          @arel_table = nil
          @column_names = nil
          @symbol_column_to_string_name_hash = nil
          @attribute_types = nil
          @content_columns = nil
          @default_attributes = nil
          @column_defaults = nil
          @inheritance_column = nil unless defined?(@explicit_inheritance_column) && @explicit_inheritance_column
          @attributes_builder = nil
          @columns = nil
          @columns_hash = nil
          @schema_loaded = false
          @attribute_names = nil
          @yaml_encoder = nil
          direct_descendants.each do |descendant|
            descendant.send(:reload_schema_from_cache)
          end
        end

        # Guesses the table name, but does not decorate it with prefix and suffix information.
        def undecorated_table_name(class_name = base_class.name)
          table_name = class_name.to_s.demodulize.underscore
          pluralize_table_names ? table_name.pluralize : table_name
        end

        # Computes and returns a table name according to default conventions.
        def compute_table_name
          if base_class?
            # Nested classes are prefixed with singular parent table name.
            if module_parent < Base && !module_parent.abstract_class?
              contained = module_parent.table_name
              contained = contained.singularize if module_parent.pluralize_table_names
              contained += "_"
            end

            "#{full_table_name_prefix}#{contained}#{undecorated_table_name(name)}#{full_table_name_suffix}"
          else
            # STI subclasses always use their superclass' table.
            base_class.table_name
          end
        end

        def _convert_type_from_options(type)
          if immutable_strings_by_default && type.respond_to?(:to_immutable_string)
            type.to_immutable_string
          else
            type
          end
        end
    end
  end
end
