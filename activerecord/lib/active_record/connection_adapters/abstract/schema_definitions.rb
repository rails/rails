# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    # Abstract representation of an index definition on a table. Instances of
    # this type are typically created and returned by methods in database
    # adapters. e.g. ActiveRecord::ConnectionAdapters::MySQL::SchemaStatements#indexes
    class IndexDefinition # :nodoc:
      attr_reader :table, :name, :unique, :columns, :lengths, :orders, :opclasses, :where, :type, :using, :comment

      def initialize(
        table, name,
        unique = false,
        columns = [],
        lengths: {},
        orders: {},
        opclasses: {},
        where: nil,
        type: nil,
        using: nil,
        comment: nil
      )
        @table = table
        @name = name
        @unique = unique
        @columns = columns
        @lengths = concise_options(lengths)
        @orders = concise_options(orders)
        @opclasses = concise_options(opclasses)
        @where = where
        @type = type
        @using = using
        @comment = comment
      end

      def column_options
        {
          length: lengths,
          order: orders,
          opclass: opclasses,
        }
      end

      private
        def concise_options(options)
          if columns.size == options.size && options.values.uniq.size == 1
            options.values.first
          else
            options
          end
        end
    end

    # Abstract representation of a column definition. Instances of this type
    # are typically created by methods in TableDefinition, and added to the
    # +columns+ attribute of said TableDefinition object, in order to be used
    # for generating a number of table creation or table changing SQL statements.
    ColumnDefinition = Struct.new(:name, :type, :options, :sql_type) do # :nodoc:
      def primary_key?
        options[:primary_key]
      end

      [:limit, :precision, :scale, :default, :null, :collation, :comment].each do |option_name|
        module_eval <<-CODE, __FILE__, __LINE__ + 1
          def #{option_name}
            options[:#{option_name}]
          end

          def #{option_name}=(value)
            options[:#{option_name}] = value
          end
        CODE
      end

      def aliased_types(name, fallback)
        "timestamp" == name ? :datetime : fallback
      end
    end

    AddColumnDefinition = Struct.new(:column) # :nodoc:

    ChangeColumnDefinition = Struct.new(:column, :name) # :nodoc:

    CreateIndexDefinition = Struct.new(:index, :algorithm, :if_not_exists) # :nodoc:

    PrimaryKeyDefinition = Struct.new(:name) # :nodoc:

    ForeignKeyDefinition = Struct.new(:from_table, :to_table, :options) do # :nodoc:
      def name
        options[:name]
      end

      def column
        options[:column]
      end

      def primary_key
        options[:primary_key] || default_primary_key
      end

      def on_delete
        options[:on_delete]
      end

      def on_update
        options[:on_update]
      end

      def deferrable
        options[:deferrable]
      end

      def custom_primary_key?
        options[:primary_key] != default_primary_key
      end

      def validate?
        options.fetch(:validate, true)
      end
      alias validated? validate?

      def export_name_on_schema_dump?
        !ActiveRecord::SchemaDumper.fk_ignore_pattern.match?(name) if name
      end

      def defined_for?(to_table: nil, validate: nil, **options)
        (to_table.nil? || to_table.to_s == self.to_table) &&
          (validate.nil? || validate == options.fetch(:validate, validate)) &&
          options.all? { |k, v| self.options[k].to_s == v.to_s }
      end

      private
        def default_primary_key
          "id"
        end
    end

    CheckConstraintDefinition = Struct.new(:table_name, :expression, :options) do
      def name
        options[:name]
      end

      def validate?
        options.fetch(:validate, true)
      end
      alias validated? validate?

      def export_name_on_schema_dump?
        !ActiveRecord::SchemaDumper.chk_ignore_pattern.match?(name) if name
      end
    end

    class ReferenceDefinition # :nodoc:
      def initialize(
        name,
        polymorphic: false,
        index: true,
        foreign_key: false,
        type: :bigint,
        **options
      )
        @name = name
        @polymorphic = polymorphic
        @index = index
        @foreign_key = foreign_key
        @type = type
        @options = options

        if polymorphic && foreign_key
          raise ArgumentError, "Cannot add a foreign key to a polymorphic relation"
        end
      end

      def add_to(table)
        columns.each do |name, type, options|
          table.column(name, type, **options)
        end

        if index
          table.index(column_names, **index_options(table.name))
        end

        if foreign_key
          table.foreign_key(foreign_table_name, **foreign_key_options)
        end
      end

      private
        attr_reader :name, :polymorphic, :index, :foreign_key, :type, :options

        def as_options(value)
          value.is_a?(Hash) ? value : {}
        end

        def polymorphic_options
          as_options(polymorphic).merge(options.slice(:null, :first, :after))
        end

        def polymorphic_index_name(table_name)
          "index_#{table_name}_on_#{name}"
        end

        def index_options(table_name)
          index_options = as_options(index)

          # legacy reference index names are used on versions 6.0 and earlier
          return index_options if options[:_uses_legacy_reference_index_name]

          index_options[:name] ||= polymorphic_index_name(table_name) if polymorphic
          index_options
        end

        def foreign_key_options
          as_options(foreign_key).merge(column: column_name)
        end

        def columns
          result = [[column_name, type, options]]
          if polymorphic
            result.unshift(["#{name}_type", :string, polymorphic_options])
          end
          result
        end

        def column_name
          "#{name}_id"
        end

        def column_names
          columns.map(&:first)
        end

        def foreign_table_name
          foreign_key_options.fetch(:to_table) do
            Base.pluralize_table_names ? name.to_s.pluralize : name
          end
        end
    end

    module ColumnMethods
      extend ActiveSupport::Concern

      # Appends a primary key definition to the table definition.
      # Can be called multiple times, but this is probably not a good idea.
      def primary_key(name, type = :primary_key, **options)
        column(name, type, **options.merge(primary_key: true))
      end

      ##
      # :method: column
      # :call-seq: column(name, type, **options)
      #
      # Appends a column or columns of a specified type.
      #
      #  t.string(:goat)
      #  t.string(:goat, :sheep)
      #
      # See TableDefinition#column

      included do
        define_column_methods :bigint, :binary, :boolean, :date, :datetime, :decimal,
          :float, :integer, :json, :string, :text, :time, :timestamp, :virtual

        alias :blob :binary
        alias :numeric :decimal
      end

      class_methods do
        def define_column_methods(*column_types) # :nodoc:
          column_types.each do |column_type|
            module_eval <<-RUBY, __FILE__, __LINE__ + 1
              def #{column_type}(*names, **options)
                raise ArgumentError, "Missing column name(s) for #{column_type}" if names.empty?
                names.each { |name| column(name, :#{column_type}, **options) }
              end
            RUBY
          end
        end
        private :define_column_methods
      end
    end

    # Represents the schema of an SQL table in an abstract way. This class
    # provides methods for manipulating the schema representation.
    #
    # Inside migration files, the +t+ object in {create_table}[rdoc-ref:SchemaStatements#create_table]
    # is actually of this type:
    #
    #   class SomeMigration < ActiveRecord::Migration[7.0]
    #     def up
    #       create_table :foo do |t|
    #         puts t.class  # => "ActiveRecord::ConnectionAdapters::TableDefinition"
    #       end
    #     end
    #
    #     def down
    #       ...
    #     end
    #   end
    #
    class TableDefinition
      include ColumnMethods

      attr_reader :name, :temporary, :if_not_exists, :options, :as, :comment, :indexes, :foreign_keys, :check_constraints

      def initialize(
        conn,
        name,
        temporary: false,
        if_not_exists: false,
        options: nil,
        as: nil,
        comment: nil,
        **
      )
        @conn = conn
        @columns_hash = {}
        @indexes = []
        @foreign_keys = []
        @primary_keys = nil
        @check_constraints = []
        @temporary = temporary
        @if_not_exists = if_not_exists
        @options = options
        @as = as
        @name = name
        @comment = comment
      end

      def primary_keys(name = nil) # :nodoc:
        @primary_keys = PrimaryKeyDefinition.new(name) if name
        @primary_keys
      end

      # Returns an array of ColumnDefinition objects for the columns of the table.
      def columns; @columns_hash.values; end

      # Returns a ColumnDefinition for the column with name +name+.
      def [](name)
        @columns_hash[name.to_s]
      end

      # Instantiates a new column for the table.
      # See {connection.add_column}[rdoc-ref:ConnectionAdapters::SchemaStatements#add_column]
      # for available options.
      #
      # Additional options are:
      # * <tt>:index</tt> -
      #   Create an index for the column. Can be either <tt>true</tt> or an options hash.
      #
      # This method returns <tt>self</tt>.
      #
      # == Examples
      #
      #  # Assuming +td+ is an instance of TableDefinition
      #  td.column(:granted, :boolean, index: true)
      #
      # == Short-hand examples
      #
      # Instead of calling #column directly, you can also work with the short-hand definitions for the default types.
      # They use the type as the method name instead of as a parameter and allow for multiple columns to be defined
      # in a single statement.
      #
      # What can be written like this with the regular calls to column:
      #
      #   create_table :products do |t|
      #     t.column :shop_id,     :integer
      #     t.column :creator_id,  :integer
      #     t.column :item_number, :string
      #     t.column :name,        :string, default: "Untitled"
      #     t.column :value,       :string, default: "Untitled"
      #     t.column :created_at,  :datetime
      #     t.column :updated_at,  :datetime
      #   end
      #   add_index :products, :item_number
      #
      # can also be written as follows using the short-hand:
      #
      #   create_table :products do |t|
      #     t.integer :shop_id, :creator_id
      #     t.string  :item_number, index: true
      #     t.string  :name, :value, default: "Untitled"
      #     t.timestamps null: false
      #   end
      #
      # There's a short-hand method for each of the type values declared at the top. And then there's
      # TableDefinition#timestamps that'll add +created_at+ and +updated_at+ as datetimes.
      #
      # TableDefinition#references will add an appropriately-named _id column, plus a corresponding _type
      # column if the <tt>:polymorphic</tt> option is supplied. If <tt>:polymorphic</tt> is a hash of
      # options, these will be used when creating the <tt>_type</tt> column. The <tt>:index</tt> option
      # will also create an index, similar to calling {add_index}[rdoc-ref:ConnectionAdapters::SchemaStatements#add_index].
      # So what can be written like this:
      #
      #   create_table :taggings do |t|
      #     t.integer :tag_id, :tagger_id, :taggable_id
      #     t.string  :tagger_type
      #     t.string  :taggable_type, default: 'Photo'
      #   end
      #   add_index :taggings, :tag_id, name: 'index_taggings_on_tag_id'
      #   add_index :taggings, [:tagger_id, :tagger_type]
      #
      # Can also be written as follows using references:
      #
      #   create_table :taggings do |t|
      #     t.references :tag, index: { name: 'index_taggings_on_tag_id' }
      #     t.references :tagger, polymorphic: true
      #     t.references :taggable, polymorphic: { default: 'Photo' }, index: false
      #   end
      def column(name, type, index: nil, **options)
        name = name.to_s
        type = type.to_sym if type

        raise_on_duplicate_column(name)
        @columns_hash[name] = new_column_definition(name, type, **options)

        if index
          index_options = index.is_a?(Hash) ? index : {}
          index(name, **index_options)
        end

        self
      end

      # remove the column +name+ from the table.
      #   remove_column(:account_id)
      def remove_column(name)
        @columns_hash.delete name.to_s
      end

      # Adds index options to the indexes hash, keyed by column name
      # This is primarily used to track indexes that need to be created after the table
      #
      #   index(:account_id, name: 'index_projects_on_account_id')
      def index(column_name, **options)
        indexes << [column_name, options]
      end

      def foreign_key(to_table, **options)
        foreign_keys << new_foreign_key_definition(to_table, options)
      end

      def check_constraint(expression, **options)
        check_constraints << new_check_constraint_definition(expression, options)
      end

      # Appends <tt>:datetime</tt> columns <tt>:created_at</tt> and
      # <tt>:updated_at</tt> to the table. See {connection.add_timestamps}[rdoc-ref:SchemaStatements#add_timestamps]
      #
      #   t.timestamps null: false
      def timestamps(**options)
        options[:null] = false if options[:null].nil?

        if !options.key?(:precision) && @conn.supports_datetime_with_precision?
          options[:precision] = 6
        end

        column(:created_at, :datetime, **options)
        column(:updated_at, :datetime, **options)
      end

      # Adds a reference.
      #
      #  t.references(:user)
      #  t.belongs_to(:supplier, foreign_key: true)
      #  t.belongs_to(:supplier, foreign_key: true, type: :integer)
      #
      # See {connection.add_reference}[rdoc-ref:SchemaStatements#add_reference] for details of the options you can use.
      def references(*args, **options)
        args.each do |ref_name|
          ReferenceDefinition.new(ref_name, **options).add_to(self)
        end
      end
      alias :belongs_to :references

      def new_column_definition(name, type, **options) # :nodoc:
        if integer_like_primary_key?(type, options)
          type = integer_like_primary_key_type(type, options)
        end
        type = aliased_types(type.to_s, type)

        if @conn.supports_datetime_with_precision?
          if type == :datetime && !options.key?(:precision)
            options[:precision] = 6
          end
        end

        options[:primary_key] ||= type == :primary_key
        options[:null] = false if options[:primary_key]
        create_column_definition(name, type, options)
      end

      def new_foreign_key_definition(to_table, options) # :nodoc:
        prefix = ActiveRecord::Base.table_name_prefix
        suffix = ActiveRecord::Base.table_name_suffix
        to_table = "#{prefix}#{to_table}#{suffix}"
        options = @conn.foreign_key_options(name, to_table, options)
        ForeignKeyDefinition.new(name, to_table, options)
      end

      def new_check_constraint_definition(expression, options) # :nodoc:
        options = @conn.check_constraint_options(name, expression, options)
        CheckConstraintDefinition.new(name, expression, options)
      end

      private
        def create_column_definition(name, type, options)
          ColumnDefinition.new(name, type, options)
        end

        def aliased_types(name, fallback)
          "timestamp" == name ? :datetime : fallback
        end

        def integer_like_primary_key?(type, options)
          options[:primary_key] && [:integer, :bigint].include?(type) && !options.key?(:default)
        end

        def integer_like_primary_key_type(type, options)
          type
        end

        def raise_on_duplicate_column(name)
          if @columns_hash[name]
            if @columns_hash[name].primary_key?
              raise ArgumentError, "you can't redefine the primary key column '#{name}'. To define a custom primary key, pass { id: false } to create_table."
            else
              raise ArgumentError, "you can't define an already defined column '#{name}'."
            end
          end
        end
    end

    class AlterTable # :nodoc:
      attr_reader :adds
      attr_reader :foreign_key_adds, :foreign_key_drops
      attr_reader :check_constraint_adds, :check_constraint_drops

      def initialize(td)
        @td   = td
        @adds = []
        @foreign_key_adds = []
        @foreign_key_drops = []
        @check_constraint_adds = []
        @check_constraint_drops = []
      end

      def name; @td.name; end

      def add_foreign_key(to_table, options)
        @foreign_key_adds << @td.new_foreign_key_definition(to_table, options)
      end

      def drop_foreign_key(name)
        @foreign_key_drops << name
      end

      def add_check_constraint(expression, options)
        @check_constraint_adds << @td.new_check_constraint_definition(expression, options)
      end

      def drop_check_constraint(constraint_name)
        @check_constraint_drops << constraint_name
      end

      def add_column(name, type, **options)
        name = name.to_s
        type = type.to_sym
        @adds << AddColumnDefinition.new(@td.new_column_definition(name, type, **options))
      end
    end

    # Represents an SQL table in an abstract way for updating a table.
    # Also see TableDefinition and {connection.create_table}[rdoc-ref:SchemaStatements#create_table]
    #
    # Available transformations are:
    #
    #   change_table :table do |t|
    #     t.primary_key
    #     t.column
    #     t.index
    #     t.rename_index
    #     t.timestamps
    #     t.change
    #     t.change_default
    #     t.change_null
    #     t.rename
    #     t.references
    #     t.belongs_to
    #     t.check_constraint
    #     t.string
    #     t.text
    #     t.integer
    #     t.bigint
    #     t.float
    #     t.decimal
    #     t.numeric
    #     t.datetime
    #     t.timestamp
    #     t.time
    #     t.date
    #     t.binary
    #     t.blob
    #     t.boolean
    #     t.foreign_key
    #     t.json
    #     t.virtual
    #     t.remove
    #     t.remove_foreign_key
    #     t.remove_references
    #     t.remove_belongs_to
    #     t.remove_index
    #     t.remove_check_constraint
    #     t.remove_timestamps
    #   end
    #
    class Table
      include ColumnMethods

      attr_reader :name

      def initialize(table_name, base)
        @name = table_name
        @base = base
      end

      # Adds a new column to the named table.
      #
      #  t.column(:name, :string)
      #
      # See TableDefinition#column for details of the options you can use.
      def column(column_name, type, index: nil, **options)
        @base.add_column(name, column_name, type, **options)
        if index
          index_options = index.is_a?(Hash) ? index : {}
          index(column_name, **index_options)
        end
      end

      # Checks to see if a column exists.
      #
      #  t.string(:name) unless t.column_exists?(:name, :string)
      #
      # See {connection.column_exists?}[rdoc-ref:SchemaStatements#column_exists?]
      def column_exists?(column_name, type = nil, **options)
        @base.column_exists?(name, column_name, type, **options)
      end

      # Adds a new index to the table. +column_name+ can be a single Symbol, or
      # an Array of Symbols.
      #
      #  t.index(:name)
      #  t.index([:branch_id, :party_id], unique: true)
      #  t.index([:branch_id, :party_id], unique: true, name: 'by_branch_party')
      #
      # See {connection.add_index}[rdoc-ref:SchemaStatements#add_index] for details of the options you can use.
      def index(column_name, **options)
        @base.add_index(name, column_name, **options)
      end

      # Checks to see if an index exists.
      #
      #  unless t.index_exists?(:branch_id)
      #    t.index(:branch_id)
      #  end
      #
      # See {connection.index_exists?}[rdoc-ref:SchemaStatements#index_exists?]
      def index_exists?(column_name, **options)
        @base.index_exists?(name, column_name, **options)
      end

      # Renames the given index on the table.
      #
      #  t.rename_index(:user_id, :account_id)
      #
      # See {connection.rename_index}[rdoc-ref:SchemaStatements#rename_index]
      def rename_index(index_name, new_index_name)
        @base.rename_index(name, index_name, new_index_name)
      end

      # Adds timestamps (+created_at+ and +updated_at+) columns to the table.
      #
      #  t.timestamps(null: false)
      #
      # See {connection.add_timestamps}[rdoc-ref:SchemaStatements#add_timestamps]
      def timestamps(**options)
        @base.add_timestamps(name, **options)
      end

      # Changes the column's definition according to the new options.
      #
      #  t.change(:name, :string, limit: 80)
      #  t.change(:description, :text)
      #
      # See TableDefinition#column for details of the options you can use.
      def change(column_name, type, **options)
        @base.change_column(name, column_name, type, **options)
      end

      # Sets a new default value for a column.
      #
      #  t.change_default(:qualification, 'new')
      #  t.change_default(:authorized, 1)
      #  t.change_default(:status, from: nil, to: "draft")
      #
      # See {connection.change_column_default}[rdoc-ref:SchemaStatements#change_column_default]
      def change_default(column_name, default_or_changes)
        @base.change_column_default(name, column_name, default_or_changes)
      end

      # Sets or removes a NOT NULL constraint on a column.
      #
      #  t.change_null(:qualification, true)
      #  t.change_null(:qualification, false, 0)
      #
      # See {connection.change_column_null}[rdoc-ref:SchemaStatements#change_column_null]
      def change_null(column_name, null, default = nil)
        @base.change_column_null(name, column_name, null, default)
      end

      # Removes the column(s) from the table definition.
      #
      #  t.remove(:qualification)
      #  t.remove(:qualification, :experience)
      #
      # See {connection.remove_columns}[rdoc-ref:SchemaStatements#remove_columns]
      def remove(*column_names, **options)
        @base.remove_columns(name, *column_names, **options)
      end

      # Removes the given index from the table.
      #
      #   t.remove_index(:branch_id)
      #   t.remove_index(column: [:branch_id, :party_id])
      #   t.remove_index(name: :by_branch_party)
      #   t.remove_index(:branch_id, name: :by_branch_party)
      #
      # See {connection.remove_index}[rdoc-ref:SchemaStatements#remove_index]
      def remove_index(column_name = nil, **options)
        @base.remove_index(name, column_name, **options)
      end

      # Removes the timestamp columns (+created_at+ and +updated_at+) from the table.
      #
      #  t.remove_timestamps
      #
      # See {connection.remove_timestamps}[rdoc-ref:SchemaStatements#remove_timestamps]
      def remove_timestamps(**options)
        @base.remove_timestamps(name, **options)
      end

      # Renames a column.
      #
      #  t.rename(:description, :name)
      #
      # See {connection.rename_column}[rdoc-ref:SchemaStatements#rename_column]
      def rename(column_name, new_column_name)
        @base.rename_column(name, column_name, new_column_name)
      end

      # Adds a reference.
      #
      #  t.references(:user)
      #  t.belongs_to(:supplier, foreign_key: true)
      #
      # See {connection.add_reference}[rdoc-ref:SchemaStatements#add_reference] for details of the options you can use.
      def references(*args, **options)
        args.each do |ref_name|
          @base.add_reference(name, ref_name, **options)
        end
      end
      alias :belongs_to :references

      # Removes a reference. Optionally removes a +type+ column.
      #
      #  t.remove_references(:user)
      #  t.remove_belongs_to(:supplier, polymorphic: true)
      #
      # See {connection.remove_reference}[rdoc-ref:SchemaStatements#remove_reference]
      def remove_references(*args, **options)
        args.each do |ref_name|
          @base.remove_reference(name, ref_name, **options)
        end
      end
      alias :remove_belongs_to :remove_references

      # Adds a foreign key to the table using a supplied table name.
      #
      #  t.foreign_key(:authors)
      #  t.foreign_key(:authors, column: :author_id, primary_key: "id")
      #
      # See {connection.add_foreign_key}[rdoc-ref:SchemaStatements#add_foreign_key]
      def foreign_key(*args, **options)
        @base.add_foreign_key(name, *args, **options)
      end

      # Removes the given foreign key from the table.
      #
      #  t.remove_foreign_key(:authors)
      #  t.remove_foreign_key(column: :author_id)
      #
      # See {connection.remove_foreign_key}[rdoc-ref:SchemaStatements#remove_foreign_key]
      def remove_foreign_key(*args, **options)
        @base.remove_foreign_key(name, *args, **options)
      end

      # Checks to see if a foreign key exists.
      #
      #  t.foreign_key(:authors) unless t.foreign_key_exists?(:authors)
      #
      # See {connection.foreign_key_exists?}[rdoc-ref:SchemaStatements#foreign_key_exists?]
      def foreign_key_exists?(*args, **options)
        @base.foreign_key_exists?(name, *args, **options)
      end

      # Adds a check constraint.
      #
      #  t.check_constraint("price > 0", name: "price_check")
      #
      # See {connection.add_check_constraint}[rdoc-ref:SchemaStatements#add_check_constraint]
      def check_constraint(*args, **options)
        @base.add_check_constraint(name, *args, **options)
      end

      # Removes the given check constraint from the table.
      #
      #  t.remove_check_constraint(name: "price_check")
      #
      # See {connection.remove_check_constraint}[rdoc-ref:SchemaStatements#remove_check_constraint]
      def remove_check_constraint(*args, **options)
        @base.remove_check_constraint(name, *args, **options)
      end
    end
  end
end
