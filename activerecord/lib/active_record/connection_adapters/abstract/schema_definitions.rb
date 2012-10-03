require 'date'
require 'set'
require 'bigdecimal'
require 'bigdecimal/util'

module ActiveRecord
  module ConnectionAdapters #:nodoc:
    # Abstract representation of an index definition on a table. Instances of
    # this type are typically created and returned by methods in database
    # adapters. e.g. ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter#indexes
    class IndexDefinition < Struct.new(:table, :name, :unique, :columns, :lengths, :orders, :where, :type) #:nodoc:
    end

    # Abstract representation of a column definition. Instances of this type
    # are typically created by methods in TableDefinition, and added to the
    # +columns+ attribute of said TableDefinition object, in order to be used
    # for generating a number of table creation or table changing SQL statements.
    class ColumnDefinition < Struct.new(:base, :name, :type, :limit, :precision, :scale, :default, :null) #:nodoc:

      def string_to_binary(value)
        value
      end

      def sql_type
        base.type_to_sql(type.to_sym, limit, precision, scale)
      end

      def to_sql
        column_sql = "#{base.quote_column_name(name)} #{sql_type}"
        column_options = {}
        column_options[:null] = null unless null.nil?
        column_options[:default] = default unless default.nil?
        add_column_options!(column_sql, column_options) unless type.to_sym == :primary_key
        column_sql
      end

      private

        def add_column_options!(sql, options)
          base.add_column_options!(sql, options.merge(:column => self))
        end
    end

    # Represents the schema of an SQL table in an abstract way. This class
    # provides methods for manipulating the schema representation.
    #
    # Inside migration files, the +t+ object in +create_table+ and
    # +change_table+ is actually of this type:
    #
    #   class SomeMigration < ActiveRecord::Migration
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
    # The table definitions
    # The Columns are stored as a ColumnDefinition in the +columns+ attribute.
    class TableDefinition
      # An array of ColumnDefinition objects, representing the column changes
      # that have been defined.
      attr_accessor :columns, :indexes

      def initialize(base)
        @columns = []
        @columns_hash = {}
        @indexes = {}
        @base = base
      end

      def xml(*args)
        raise NotImplementedError unless %w{
          sqlite mysql mysql2
        }.include? @base.adapter_name.downcase

        options = args.extract_options!
        column(args[0], :text, options)
      end

      # Appends a primary key definition to the table definition.
      # Can be called multiple times, but this is probably not a good idea.
      def primary_key(name)
        column(name, :primary_key)
      end

      # Returns a ColumnDefinition for the column with name +name+.
      def [](name)
        @columns_hash[name.to_s]
      end

      # Instantiates a new column for the table.
      # The +type+ parameter is normally one of the migrations native types,
      # which is one of the following:
      # <tt>:primary_key</tt>, <tt>:string</tt>, <tt>:text</tt>,
      # <tt>:integer</tt>, <tt>:float</tt>, <tt>:decimal</tt>,
      # <tt>:datetime</tt>, <tt>:timestamp</tt>, <tt>:time</tt>,
      # <tt>:date</tt>, <tt>:binary</tt>, <tt>:boolean</tt>.
      #
      # You may use a type not in this list as long as it is supported by your
      # database (for example, "polygon" in MySQL), but this will not be database
      # agnostic and should usually be avoided.
      #
      # Available options are (none of these exists by default):
      # * <tt>:limit</tt> -
      #   Requests a maximum column length. This is number of characters for <tt>:string</tt> and
      #   <tt>:text</tt> columns and number of bytes for <tt>:binary</tt> and <tt>:integer</tt> columns.
      # * <tt>:default</tt> -
      #   The column's default value. Use nil for NULL.
      # * <tt>:null</tt> -
      #   Allows or disallows +NULL+ values in the column. This option could
      #   have been named <tt>:null_allowed</tt>.
      # * <tt>:precision</tt> -
      #   Specifies the precision for a <tt>:decimal</tt> column.
      # * <tt>:scale</tt> -
      #   Specifies the scale for a <tt>:decimal</tt> column.
      #
      # For clarity's sake: the precision is the number of significant digits,
      # while the scale is the number of digits that can be stored following
      # the decimal point. For example, the number 123.45 has a precision of 5
      # and a scale of 2. A decimal with a precision of 5 and a scale of 2 can
      # range from -999.99 to 999.99.
      #
      # Please be aware of different RDBMS implementations behavior with
      # <tt>:decimal</tt> columns:
      # * The SQL standard says the default scale should be 0, <tt>:scale</tt> <=
      #   <tt>:precision</tt>, and makes no comments about the requirements of
      #   <tt>:precision</tt>.
      # * MySQL: <tt>:precision</tt> [1..63], <tt>:scale</tt> [0..30].
      #   Default is (10,0).
      # * PostgreSQL: <tt>:precision</tt> [1..infinity],
      #   <tt>:scale</tt> [0..infinity]. No default.
      # * SQLite2: Any <tt>:precision</tt> and <tt>:scale</tt> may be used.
      #   Internal storage as strings. No default.
      # * SQLite3: No restrictions on <tt>:precision</tt> and <tt>:scale</tt>,
      #   but the maximum supported <tt>:precision</tt> is 16. No default.
      # * Oracle: <tt>:precision</tt> [1..38], <tt>:scale</tt> [-84..127].
      #   Default is (38,0).
      # * DB2: <tt>:precision</tt> [1..63], <tt>:scale</tt> [0..62].
      #   Default unknown.
      # * Firebird: <tt>:precision</tt> [1..18], <tt>:scale</tt> [0..18].
      #   Default (9,0). Internal types NUMERIC and DECIMAL have different
      #   storage rules, decimal being better.
      # * FrontBase?: <tt>:precision</tt> [1..38], <tt>:scale</tt> [0..38].
      #   Default (38,0). WARNING Max <tt>:precision</tt>/<tt>:scale</tt> for
      #   NUMERIC is 19, and DECIMAL is 38.
      # * SqlServer?: <tt>:precision</tt> [1..38], <tt>:scale</tt> [0..38].
      #   Default (38,0).
      # * Sybase: <tt>:precision</tt> [1..38], <tt>:scale</tt> [0..38].
      #   Default (38,0).
      # * OpenBase?: Documentation unclear. Claims storage in <tt>double</tt>.
      #
      # This method returns <tt>self</tt>.
      #
      # == Examples
      #  # Assuming +td+ is an instance of TableDefinition
      #  td.column(:granted, :boolean)
      #  # granted BOOLEAN
      #
      #  td.column(:picture, :binary, :limit => 2.megabytes)
      #  # => picture BLOB(2097152)
      #
      #  td.column(:sales_stage, :string, :limit => 20, :default => 'new', :null => false)
      #  # => sales_stage VARCHAR(20) DEFAULT 'new' NOT NULL
      #
      #  td.column(:bill_gates_money, :decimal, :precision => 15, :scale => 2)
      #  # => bill_gates_money DECIMAL(15,2)
      #
      #  td.column(:sensor_reading, :decimal, :precision => 30, :scale => 20)
      #  # => sensor_reading DECIMAL(30,20)
      #
      #  # While <tt>:scale</tt> defaults to zero on most databases, it
      #  # probably wouldn't hurt to include it.
      #  td.column(:huge_integer, :decimal, :precision => 30)
      #  # => huge_integer DECIMAL(30)
      #
      #  # Defines a column with a database-specific type.
      #  td.column(:foo, 'polygon')
      #  # => foo polygon
      #
      # == Short-hand examples
      #
      # Instead of calling +column+ directly, you can also work with the short-hand definitions for the default types.
      # They use the type as the method name instead of as a parameter and allow for multiple columns to be defined
      # in a single statement.
      #
      # What can be written like this with the regular calls to column:
      #
      #   create_table "products", :force => true do |t|
      #     t.column "shop_id",    :integer
      #     t.column "creator_id", :integer
      #     t.column "name",       :string,   :default => "Untitled"
      #     t.column "value",      :string,   :default => "Untitled"
      #     t.column "created_at", :datetime
      #     t.column "updated_at", :datetime
      #   end
      #
      # Can also be written as follows using the short-hand:
      #
      #   create_table :products do |t|
      #     t.integer :shop_id, :creator_id
      #     t.string  :name, :value, :default => "Untitled"
      #     t.timestamps
      #   end
      #
      # There's a short-hand method for each of the type values declared at the top. And then there's
      # TableDefinition#timestamps that'll add +created_at+ and +updated_at+ as datetimes.
      #
      # TableDefinition#references will add an appropriately-named _id column, plus a corresponding _type
      # column if the <tt>:polymorphic</tt> option is supplied. If <tt>:polymorphic</tt> is a hash of
      # options, these will be used when creating the <tt>_type</tt> column. The <tt>:index</tt> option
      # will also create an index, similar to calling <tt>add_index</tt>. So what can be written like this:
      #
      #   create_table :taggings do |t|
      #     t.integer :tag_id, :tagger_id, :taggable_id
      #     t.string  :tagger_type
      #     t.string  :taggable_type, :default => 'Photo'
      #   end
      #   add_index :taggings, :tag_id, :name => 'index_taggings_on_tag_id'
      #   add_index :taggings, [:tagger_id, :tagger_type]
      #
      # Can also be written as follows using references:
      #
      #   create_table :taggings do |t|
      #     t.references :tag, :index => { :name => 'index_taggings_on_tag_id' }
      #     t.references :tagger, :polymorphic => true, :index => true
      #     t.references :taggable, :polymorphic => { :default => 'Photo' }
      #   end
      def column(name, type, options = {})
        name = name.to_s
        type = type.to_sym

        column = self[name] || new_column_definition(@base, name, type)

        limit = options.fetch(:limit) do
          native[type][:limit] if native[type].is_a?(Hash)
        end

        column.limit     = limit
        column.precision = options[:precision]
        column.scale     = options[:scale]
        column.default   = options[:default]
        column.null      = options[:null]
        self
      end

      %w( string text integer float decimal datetime timestamp time date binary boolean ).each do |column_type|
        class_eval <<-EOV, __FILE__, __LINE__ + 1
          def #{column_type}(*args)                                   # def string(*args)
            options = args.extract_options!                           #   options = args.extract_options!
            column_names = args                                       #   column_names = args
            type = :'#{column_type}'                                  #   type = :string
            column_names.each { |name| column(name, type, options) }  #   column_names.each { |name| column(name, type, options) }
          end                                                         # end
        EOV
      end

      # Adds index options to the indexes hash, keyed by column name
      # This is primarily used to track indexes that need to be created after the table
      #
      #   index(:account_id, :name => 'index_projects_on_account_id')
      def index(column_name, options = {})
        indexes[column_name] = options
      end

      # Appends <tt>:datetime</tt> columns <tt>:created_at</tt> and
      # <tt>:updated_at</tt> to the table.
      def timestamps(*args)
        options = args.extract_options!
        column(:created_at, :datetime, options)
        column(:updated_at, :datetime, options)
      end

      def references(*args)
        options = args.extract_options!
        polymorphic = options.delete(:polymorphic)
        index_options = options.delete(:index)
        args.each do |col|
          column("#{col}_id", :integer, options)
          column("#{col}_type", :string, polymorphic.is_a?(Hash) ? polymorphic : options) if polymorphic
          index(polymorphic ? %w(id type).map { |t| "#{col}_#{t}" } : "#{col}_id", index_options.is_a?(Hash) ? index_options : nil) if index_options
        end
      end
      alias :belongs_to :references

      # Returns a String whose contents are the column definitions
      # concatenated together. This string can then be prepended and appended to
      # to generate the final SQL to create the table.
      def to_sql
        @columns.map { |c| c.to_sql } * ', '
      end

      private
      def new_column_definition(base, name, type)
        definition = ColumnDefinition.new base, name, type
        @columns << definition
        @columns_hash[name] = definition
        definition
      end

      def native
        @base.native_database_types
      end
    end

    # Represents an SQL table in an abstract way for updating a table.
    # Also see TableDefinition and SchemaStatements#create_table
    #
    # Available transformations are:
    #
    #   change_table :table do |t|
    #     t.column
    #     t.index
    #     t.timestamps
    #     t.change
    #     t.change_default
    #     t.rename
    #     t.references
    #     t.belongs_to
    #     t.string
    #     t.text
    #     t.integer
    #     t.float
    #     t.decimal
    #     t.datetime
    #     t.timestamp
    #     t.time
    #     t.date
    #     t.binary
    #     t.boolean
    #     t.remove
    #     t.remove_references
    #     t.remove_belongs_to
    #     t.remove_index
    #     t.remove_timestamps
    #   end
    #
    class Table
      def initialize(table_name, base)
        @table_name = table_name
        @base = base
      end

      # Adds a new column to the named table.
      # See TableDefinition#column for details of the options you can use.
      #
      # ====== Creating a simple column
      #  t.column(:name, :string)
      def column(column_name, type, options = {})
        @base.add_column(@table_name, column_name, type, options)
      end

      # Checks to see if a column exists. See SchemaStatements#column_exists?
      def column_exists?(column_name, type = nil, options = {})
        @base.column_exists?(@table_name, column_name, type, options)
      end

      # Adds a new index to the table. +column_name+ can be a single Symbol, or
      # an Array of Symbols. See SchemaStatements#add_index
      #
      # ====== Creating a simple index
      #  t.index(:name)
      # ====== Creating a unique index
      #  t.index([:branch_id, :party_id], :unique => true)
      # ====== Creating a named index
      #  t.index([:branch_id, :party_id], :unique => true, :name => 'by_branch_party')
      def index(column_name, options = {})
        @base.add_index(@table_name, column_name, options)
      end

      # Checks to see if an index exists. See SchemaStatements#index_exists?
      def index_exists?(column_name, options = {})
        @base.index_exists?(@table_name, column_name, options)
      end

      # Adds timestamps (+created_at+ and +updated_at+) columns to the table. See SchemaStatements#add_timestamps
      #
      #  t.timestamps
      def timestamps
        @base.add_timestamps(@table_name)
      end

      # Changes the column's definition according to the new options.
      # See TableDefinition#column for details of the options you can use.
      #
      #  t.change(:name, :string, :limit => 80)
      #  t.change(:description, :text)
      def change(column_name, type, options = {})
        @base.change_column(@table_name, column_name, type, options)
      end

      # Sets a new default value for a column. See SchemaStatements#change_column_default
      #
      #  t.change_default(:qualification, 'new')
      #  t.change_default(:authorized, 1)
      def change_default(column_name, default)
        @base.change_column_default(@table_name, column_name, default)
      end

      # Removes the column(s) from the table definition.
      #
      #  t.remove(:qualification)
      #  t.remove(:qualification, :experience)
      def remove(*column_names)
        @base.remove_column(@table_name, *column_names)
      end

      # Removes the given index from the table.
      #
      # ====== Remove the index_table_name_on_column in the table_name table
      #   t.remove_index :column
      # ====== Remove the index named index_table_name_on_branch_id in the table_name table
      #   t.remove_index :column => :branch_id
      # ====== Remove the index named index_table_name_on_branch_id_and_party_id in the table_name table
      #   t.remove_index :column => [:branch_id, :party_id]
      # ====== Remove the index named by_branch_party in the table_name table
      #   t.remove_index :name => :by_branch_party
      def remove_index(options = {})
        @base.remove_index(@table_name, options)
      end

      # Removes the timestamp columns (+created_at+ and +updated_at+) from the table.
      #
      #  t.remove_timestamps
      def remove_timestamps
        @base.remove_timestamps(@table_name)
      end

      # Renames a column.
      #
      #  t.rename(:description, :name)
      def rename(column_name, new_column_name)
        @base.rename_column(@table_name, column_name, new_column_name)
      end

      # Adds a reference. Optionally adds a +type+ column, if <tt>:polymorphic</tt> option is provided.
      # <tt>references</tt> and <tt>belongs_to</tt> are acceptable.
      #
      #  t.references(:user)
      #  t.belongs_to(:supplier, polymorphic: true)
      #
      def references(*args)
        options = args.extract_options!
        args.each do |ref_name|
          @base.add_reference(@table_name, ref_name, options)
        end
      end
      alias :belongs_to :references

      # Removes a reference. Optionally removes a +type+ column.
      # <tt>remove_references</tt> and <tt>remove_belongs_to</tt> are acceptable.
      #
      #  t.remove_references(:user)
      #  t.remove_belongs_to(:supplier, polymorphic: true)
      #
      def remove_references(*args)
        options = args.extract_options!
        args.each do |ref_name|
          @base.remove_reference(@table_name, ref_name, options)
        end
      end
      alias :remove_belongs_to :remove_references

      # Adds a column or columns of a specified type
      #
      #  t.string(:goat)
      #  t.string(:goat, :sheep)
      %w( string text integer float decimal datetime timestamp time date binary boolean ).each do |column_type|
        class_eval <<-EOV, __FILE__, __LINE__ + 1
          def #{column_type}(*args)                                          # def string(*args)
            options = args.extract_options!                                  #   options = args.extract_options!
            column_names = args                                              #   column_names = args
            type = :'#{column_type}'                                         #   type = :string
            column_names.each do |name|                                      #   column_names.each do |name|
              column = ColumnDefinition.new(@base, name.to_s, type)          #     column = ColumnDefinition.new(@base, name, type)
              if options[:limit]                                             #     if options[:limit]
                column.limit = options[:limit]                               #       column.limit = options[:limit]
              elsif native[type].is_a?(Hash)                                 #     elsif native[type].is_a?(Hash)
                column.limit = native[type][:limit]                          #       column.limit = native[type][:limit]
              end                                                            #     end
              column.precision = options[:precision]                         #     column.precision = options[:precision]
              column.scale = options[:scale]                                 #     column.scale = options[:scale]
              column.default = options[:default]                             #     column.default = options[:default]
              column.null = options[:null]                                   #     column.null = options[:null]
              @base.add_column(@table_name, name, column.sql_type, options)  #     @base.add_column(@table_name, name, column.sql_type, options)
            end                                                              #   end
          end                                                                # end
        EOV
      end

      private
        def native
          @base.native_database_types
        end
    end

  end
end
