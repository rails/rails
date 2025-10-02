# frozen_string_literal: true

require "active_support/core_ext/string/access"
require "active_support/core_ext/string/filters"
require "openssl"

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module SchemaStatements
      include ActiveRecord::Migration::JoinTable

      # Returns a hash of mappings from the abstract data types to the native
      # database types. See TableDefinition#column for details on the recognized
      # abstract data types.
      def native_database_types
        {}
      end

      def table_options(table_name)
        nil
      end

      # Returns the table comment that's stored in database metadata.
      def table_comment(table_name)
        nil
      end

      # Truncates a table alias according to the limits of the current adapter.
      def table_alias_for(table_name)
        table_name[0...table_alias_length].tr(".", "_")
      end

      # Returns the relation names usable to back Active Record models.
      # For most adapters this means all #tables and #views.
      def data_sources
        query_values(data_source_sql, "SCHEMA")
      rescue NotImplementedError
        tables | views
      end

      # Checks to see if the data source +name+ exists on the database.
      #
      #   data_source_exists?(:ebooks)
      #
      def data_source_exists?(name)
        query_values(data_source_sql(name), "SCHEMA").any? if name.present?
      rescue NotImplementedError
        data_sources.include?(name.to_s)
      end

      # Returns an array of table names defined in the database.
      def tables
        query_values(data_source_sql(type: "BASE TABLE"), "SCHEMA")
      end

      # Checks to see if the table +table_name+ exists on the database.
      #
      #   table_exists?(:developers)
      #
      def table_exists?(table_name)
        query_values(data_source_sql(table_name, type: "BASE TABLE"), "SCHEMA").any? if table_name.present?
      rescue NotImplementedError
        tables.include?(table_name.to_s)
      end

      # Returns an array of view names defined in the database.
      def views
        query_values(data_source_sql(type: "VIEW"), "SCHEMA")
      end

      # Checks to see if the view +view_name+ exists on the database.
      #
      #   view_exists?(:ebooks)
      #
      def view_exists?(view_name)
        query_values(data_source_sql(view_name, type: "VIEW"), "SCHEMA").any? if view_name.present?
      rescue NotImplementedError
        views.include?(view_name.to_s)
      end

      # Returns an array of indexes for the given table.
      def indexes(table_name)
        raise NotImplementedError, "#indexes is not implemented"
      end

      # Checks to see if an index exists on a table for a given index definition.
      #
      #   # Check an index exists
      #   index_exists?(:suppliers, :company_id)
      #
      #   # Check an index on multiple columns exists
      #   index_exists?(:suppliers, [:company_id, :company_type])
      #
      #   # Check a unique index exists
      #   index_exists?(:suppliers, :company_id, unique: true)
      #
      #   # Check an index with a custom name exists
      #   index_exists?(:suppliers, :company_id, name: "idx_company_id")
      #
      #   # Check a valid index exists (PostgreSQL only)
      #   index_exists?(:suppliers, :company_id, valid: true)
      #
      def index_exists?(table_name, column_name = nil, **options)
        indexes(table_name).any? { |i| i.defined_for?(column_name, **options) }
      end

      # Returns an array of +Column+ objects for the table specified by +table_name+.
      def columns(table_name)
        table_name = table_name.to_s
        definitions = column_definitions(table_name)
        definitions.map do |field|
          new_column_from_field(table_name, field, definitions)
        end
      end

      # Checks to see if a column exists in a given table.
      #
      #   # Check a column exists
      #   column_exists?(:suppliers, :name)
      #
      #   # Check a column exists of a particular type
      #   #
      #   # This works for standard non-casted types (eg. string) but is unreliable
      #   # for types that may get cast to something else (eg. char, bigint).
      #   column_exists?(:suppliers, :name, :string)
      #
      #   # Check a column exists with a specific definition
      #   column_exists?(:suppliers, :name, :string, limit: 100)
      #   column_exists?(:suppliers, :name, :string, default: 'default')
      #   column_exists?(:suppliers, :name, :string, null: false)
      #   column_exists?(:suppliers, :tax, :decimal, precision: 8, scale: 2)
      #
      def column_exists?(table_name, column_name, type = nil, **options)
        column_name = column_name.to_s
        checks = []
        checks << lambda { |c| c.name == column_name }
        checks << lambda { |c| c.type == type.to_sym rescue nil } if type
        column_options_keys.each do |attr|
          checks << lambda { |c| c.send(attr) == options[attr] } if options.key?(attr)
        end

        columns(table_name).any? { |c| checks.all? { |check| check[c] } }
      end

      # Returns just a table's primary key
      def primary_key(table_name)
        pk = primary_keys(table_name)
        pk = pk.first unless pk.size > 1
        pk
      end

      # Creates a new table with the name +table_name+. +table_name+ may either
      # be a String or a Symbol.
      #
      # There are two ways to work with #create_table. You can use the block
      # form or the regular form, like this:
      #
      # === Block form
      #
      #   # create_table() passes a TableDefinition object to the block.
      #   # This form will not only create the table, but also columns for the
      #   # table.
      #
      #   create_table(:suppliers) do |t|
      #     t.column :name, :string, limit: 60
      #     # Other fields here
      #   end
      #
      # === Block form, with shorthand
      #
      #   # You can also use the column types as method calls, rather than calling the column method.
      #   create_table(:suppliers) do |t|
      #     t.string :name, limit: 60
      #     # Other fields here
      #   end
      #
      # === Regular form
      #
      #   # Creates a table called 'suppliers' with no columns.
      #   create_table(:suppliers)
      #   # Add a column to 'suppliers'.
      #   add_column(:suppliers, :name, :string, {limit: 60})
      #
      # The +options+ hash can include the following keys:
      # [<tt>:id</tt>]
      #   Whether to automatically add a primary key column. Defaults to true.
      #   Join tables for {ActiveRecord::Base.has_and_belongs_to_many}[rdoc-ref:Associations::ClassMethods#has_and_belongs_to_many] should set it to false.
      #
      #   A Symbol can be used to specify the type of the generated primary key column.
      #
      #   A Hash can be used to specify the generated primary key column creation options.
      #   See {add_column}[rdoc-ref:ConnectionAdapters::SchemaStatements#add_column] for available options.
      # [<tt>:primary_key</tt>]
      #   The name of the primary key, if one is to be added automatically.
      #   Defaults to +id+. If <tt>:id</tt> is false, then this option is ignored.
      #
      #   If an array is passed, a composite primary key will be created.
      #
      #   Note that Active Record models will automatically detect their
      #   primary key. This can be avoided by using
      #   {self.primary_key=}[rdoc-ref:AttributeMethods::PrimaryKey::ClassMethods#primary_key=] on the model
      #   to define the key explicitly.
      #
      # [<tt>:options</tt>]
      #   Any extra options you want appended to the table definition.
      # [<tt>:temporary</tt>]
      #   Make a temporary table.
      # [<tt>:force</tt>]
      #   Set to true to drop the table before creating it.
      #   Set to +:cascade+ to drop dependent objects as well.
      #   Defaults to false.
      # [<tt>:if_not_exists</tt>]
      #   Set to true to avoid raising an error when the table already exists.
      #   Defaults to false.
      # [<tt>:as</tt>]
      #   SQL to use to generate the table. When this option is used, the block is
      #   ignored, as are the <tt>:id</tt> and <tt>:primary_key</tt> options.
      #
      # ====== Add a backend specific option to the generated SQL (MySQL)
      #
      #   create_table(:suppliers, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8mb4')
      #
      # generates:
      #
      #   CREATE TABLE suppliers (
      #     id bigint auto_increment PRIMARY KEY
      #   ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
      #
      # ====== Rename the primary key column
      #
      #   create_table(:objects, primary_key: 'guid') do |t|
      #     t.column :name, :string, limit: 80
      #   end
      #
      # generates:
      #
      #   CREATE TABLE objects (
      #     guid bigint auto_increment PRIMARY KEY,
      #     name varchar(80)
      #   )
      #
      # ====== Change the primary key column type
      #
      #   create_table(:tags, id: :string) do |t|
      #     t.column :label, :string
      #   end
      #
      # generates:
      #
      #   CREATE TABLE tags (
      #     id varchar PRIMARY KEY,
      #     label varchar
      #   )
      #
      # ====== Create a composite primary key
      #
      #   create_table(:orders, primary_key: [:product_id, :client_id]) do |t|
      #     t.belongs_to :product
      #     t.belongs_to :client
      #   end
      #
      # generates:
      #
      #   CREATE TABLE orders (
      #       product_id bigint NOT NULL,
      #       client_id bigint NOT NULL
      #   );
      #
      #   ALTER TABLE ONLY "orders"
      #     ADD CONSTRAINT orders_pkey PRIMARY KEY (product_id, client_id);
      #
      # ====== Do not add a primary key column
      #
      #   create_table(:categories_suppliers, id: false) do |t|
      #     t.column :category_id, :bigint
      #     t.column :supplier_id, :bigint
      #   end
      #
      # generates:
      #
      #   CREATE TABLE categories_suppliers (
      #     category_id bigint,
      #     supplier_id bigint
      #   )
      #
      # ====== Create a temporary table based on a query
      #
      #   create_table(:long_query, temporary: true,
      #     as: "SELECT * FROM orders INNER JOIN line_items ON order_id=orders.id")
      #
      # generates:
      #
      #   CREATE TEMPORARY TABLE long_query AS
      #     SELECT * FROM orders INNER JOIN line_items ON order_id=orders.id
      #
      # See also TableDefinition#column for details on how to create columns.
      def create_table(table_name, id: :primary_key, primary_key: nil, force: nil, **options, &block)
        validate_create_table_options!(options)
        validate_table_length!(table_name) unless options[:_uses_legacy_table_name]

        if force && options.key?(:if_not_exists)
          raise ArgumentError, "Options `:force` and `:if_not_exists` cannot be used simultaneously."
        end

        td = build_create_table_definition(table_name, id: id, primary_key: primary_key, force: force, **options, &block)

        if force
          drop_table(table_name, force: force, if_exists: true)
        else
          schema_cache.clear_data_source_cache!(table_name.to_s)
        end

        result = execute schema_creation.accept(td)

        unless supports_indexes_in_create?
          td.indexes.each do |column_name, index_options|
            add_index(table_name, column_name, **index_options, if_not_exists: td.if_not_exists)
          end
        end

        if supports_comments? && !supports_comments_in_create?
          if table_comment = td.comment.presence
            change_table_comment(table_name, table_comment)
          end

          td.columns.each do |column|
            change_column_comment(table_name, column.name, column.comment) if column.comment.present?
          end
        end

        result
      end

      # Returns a TableDefinition object containing information about the table that would be created
      # if the same arguments were passed to #create_table. See #create_table for information about
      # passing a +table_name+, and other additional options that can be passed.
      def build_create_table_definition(table_name, id: :primary_key, primary_key: nil, force: nil, **options)
        table_definition = create_table_definition(table_name, **options.extract!(*valid_table_definition_options, :_skip_validate_options))
        table_definition.set_primary_key(table_name, id, primary_key, **options.extract!(*valid_primary_key_options, :_skip_validate_options))

        yield table_definition if block_given?

        table_definition
      end

      # Creates a new join table with the name created using the lexical order of the first two
      # arguments. These arguments can be a String or a Symbol.
      #
      #   # Creates a table called 'assemblies_parts' with no id.
      #   create_join_table(:assemblies, :parts)
      #
      #   # Creates a table called 'paper_boxes_papers' with no id.
      #   create_join_table('papers', 'paper_boxes')
      #
      # A duplicate prefix is combined into a single prefix. This is useful for
      # namespaced models like Music::Artist and Music::Record:
      #
      #   # Creates a table called 'music_artists_records' with no id.
      #   create_join_table('music_artists', 'music_records')
      #
      # See {connection.add_reference}[rdoc-ref:SchemaStatements#add_reference]
      # for details of the options you can use in +column_options+. +column_options+
      # will be applied to both columns.
      #
      # You can pass an +options+ hash which can include the following keys:
      # [<tt>:table_name</tt>]
      #   Sets the table name, overriding the default.
      # [<tt>:options</tt>]
      #   Any extra options you want appended to the table definition.
      # [<tt>:temporary</tt>]
      #   Make a temporary table.
      # [<tt>:force</tt>]
      #   Set to true to drop the table before creating it.
      #   Defaults to false.
      #
      # Note that #create_join_table does not create any indices by default; you can use
      # its block form to do so yourself:
      #
      #   create_join_table :products, :categories do |t|
      #     t.index :product_id
      #     t.index :category_id
      #   end
      #
      # ====== Add foreign keys with delete cascade
      #
      #   create_join_table(:assemblies, :parts, column_options: { foreign_key: { on_delete: :cascade } })
      #
      # generates:
      #
      #   CREATE TABLE assemblies_parts (
      #     assembly_id bigint NOT NULL,
      #     part_id bigint NOT NULL,
      #     CONSTRAINT fk_rails_0d8a572d89 FOREIGN KEY ("assembly_id") REFERENCES "assemblies" ("id") ON DELETE CASCADE,
      #     CONSTRAINT fk_rails_ec7b48402b FOREIGN KEY ("part_id") REFERENCES "parts" ("id") ON DELETE CASCADE
      #   )
      #
      # ====== Add a backend specific option to the generated SQL (MySQL)
      #
      #   create_join_table(:assemblies, :parts, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8')
      #
      # generates:
      #
      #   CREATE TABLE assemblies_parts (
      #     assembly_id bigint NOT NULL,
      #     part_id bigint NOT NULL,
      #   ) ENGINE=InnoDB DEFAULT CHARSET=utf8
      #
      def create_join_table(table_1, table_2, column_options: {}, **options)
        join_table_name = find_join_table_name(table_1, table_2, options)

        column_options.reverse_merge!(null: false, index: false)

        t1_ref, t2_ref = [table_1, table_2].map { |t| reference_name_for_table(t) }

        create_table(join_table_name, **options.merge!(id: false)) do |td|
          td.references t1_ref, **column_options
          td.references t2_ref, **column_options
          yield td if block_given?
        end
      end

      # Builds a TableDefinition object for a join table.
      #
      # This definition object contains information about the table that would be created
      # if the same arguments were passed to #create_join_table. See #create_join_table for
      # information about what arguments should be passed.
      def build_create_join_table_definition(table_1, table_2, column_options: {}, **options) # :nodoc:
        join_table_name = find_join_table_name(table_1, table_2, options)
        column_options.reverse_merge!(null: false, index: false)

        t1_ref, t2_ref = [table_1, table_2].map { |t| reference_name_for_table(t) }

        build_create_table_definition(join_table_name, **options.merge!(id: false)) do |td|
          td.references t1_ref, **column_options
          td.references t2_ref, **column_options
          yield td if block_given?
        end
      end

      # Drops the join table specified by the given arguments.
      # See #create_join_table and #drop_table for details.
      #
      # Although this command ignores the block if one is given, it can be helpful
      # to provide one in a migration's +change+ method so it can be reverted.
      # In that case, the block will be used by #create_join_table.
      def drop_join_table(table_1, table_2, **options)
        join_table_name = find_join_table_name(table_1, table_2, options)
        drop_table(join_table_name, **options)
      end

      # A block for changing columns in +table+.
      #
      #   # change_table() yields a Table instance
      #   change_table(:suppliers) do |t|
      #     t.column :name, :string, limit: 60
      #     # Other column alterations here
      #   end
      #
      # The +options+ hash can include the following keys:
      # [<tt>:bulk</tt>]
      #   Set this to true to make this a bulk alter query, such as
      #
      #     ALTER TABLE `users` ADD COLUMN age INT, ADD COLUMN birthdate DATETIME ...
      #
      #   Defaults to false.
      #
      #   Only supported on the MySQL and PostgreSQL adapter, ignored elsewhere.
      #
      # ====== Add a column
      #
      #   change_table(:suppliers) do |t|
      #     t.column :name, :string, limit: 60
      #   end
      #
      # ====== Change type of a column
      #
      #   change_table(:suppliers) do |t|
      #     t.change :metadata, :json
      #   end
      #
      # ====== Add 2 integer columns
      #
      #   change_table(:suppliers) do |t|
      #     t.integer :width, :height, null: false, default: 0
      #   end
      #
      # ====== Add created_at/updated_at columns
      #
      #   change_table(:suppliers) do |t|
      #     t.timestamps
      #   end
      #
      # ====== Add a foreign key column
      #
      #   change_table(:suppliers) do |t|
      #     t.references :company
      #   end
      #
      # Creates a <tt>company_id(bigint)</tt> column.
      #
      # ====== Add a polymorphic foreign key column
      #
      #  change_table(:suppliers) do |t|
      #    t.belongs_to :company, polymorphic: true
      #  end
      #
      # Creates <tt>company_type(varchar)</tt> and <tt>company_id(bigint)</tt> columns.
      #
      # ====== Remove a column
      #
      #  change_table(:suppliers) do |t|
      #    t.remove :company
      #  end
      #
      # ====== Remove several columns
      #
      #  change_table(:suppliers) do |t|
      #    t.remove :company_id
      #    t.remove :width, :height
      #  end
      #
      # ====== Remove an index
      #
      #  change_table(:suppliers) do |t|
      #    t.remove_index :company_id
      #  end
      #
      # See also Table for details on all of the various column transformations.
      def change_table(table_name, base = self, **options)
        if supports_bulk_alter? && options[:bulk]
          recorder = ActiveRecord::Migration::CommandRecorder.new(self)
          yield update_table_definition(table_name, recorder)
          bulk_change_table(table_name, recorder.commands)
        else
          yield update_table_definition(table_name, base)
        end
      end

      # Renames a table.
      #
      #   rename_table('octopuses', 'octopi')
      #
      def rename_table(table_name, new_name, **)
        raise NotImplementedError, "rename_table is not implemented"
      end

      # Drops a table or tables from the database.
      #
      # [<tt>:force</tt>]
      #   Set to +:cascade+ to drop dependent objects as well.
      #   Defaults to false.
      # [<tt>:if_exists</tt>]
      #   Set to +true+ to only drop the table if it exists.
      #   Defaults to false.
      #
      # Although this command ignores most +options+ and the block if one is given,
      # it can be helpful to provide these in a migration's +change+ method so it can be reverted.
      # In that case, +options+ and the block will be used by #create_table except if you provide more than one table which is not supported.
      def drop_table(*table_names, **options)
        table_names.each do |table_name|
          schema_cache.clear_data_source_cache!(table_name.to_s)
          execute "DROP TABLE#{' IF EXISTS' if options[:if_exists]} #{quote_table_name(table_name)}"
        end
      end

      # Add a new +type+ column named +column_name+ to +table_name+.
      #
      # See {ActiveRecord::ConnectionAdapters::TableDefinition.column}[rdoc-ref:ActiveRecord::ConnectionAdapters::TableDefinition#column].
      #
      # The +type+ parameter is normally one of the migration's native types,
      # which is one of the following:
      # <tt>:primary_key</tt>, <tt>:string</tt>, <tt>:text</tt>,
      # <tt>:integer</tt>, <tt>:bigint</tt>, <tt>:float</tt>, <tt>:decimal</tt>, <tt>:numeric</tt>,
      # <tt>:datetime</tt>, <tt>:time</tt>, <tt>:date</tt>,
      # <tt>:binary</tt>, <tt>:blob</tt>, <tt>:boolean</tt>.
      #
      # You may use a type not in this list as long as it is supported by your
      # database (for example, "polygon" in MySQL), but this will not be database
      # agnostic and should usually be avoided.
      #
      # Available options are (none of these exists by default):
      # * <tt>:comment</tt> -
      #   Specifies the comment for the column. This option is ignored by some backends.
      # * <tt>:collation</tt> -
      #   Specifies the collation for a <tt>:string</tt> or <tt>:text</tt> column.
      #   If not specified, the column will have the same collation as the table.
      # * <tt>:default</tt> -
      #   The column's default value. Use +nil+ for +NULL+.
      # * <tt>:limit</tt> -
      #   Requests a maximum column length. This is the number of characters for a <tt>:string</tt> column
      #   and number of bytes for <tt>:text</tt>, <tt>:binary</tt>, <tt>:blob</tt>, and <tt>:integer</tt> columns.
      #   This option is ignored by some backends.
      # * <tt>:null</tt> -
      #   Allows or disallows +NULL+ values in the column.
      # * <tt>:precision</tt> -
      #   Specifies the precision for the <tt>:decimal</tt>, <tt>:numeric</tt>,
      #   <tt>:datetime</tt>, and <tt>:time</tt> columns.
      # * <tt>:scale</tt> -
      #   Specifies the scale for the <tt>:decimal</tt> and <tt>:numeric</tt> columns.
      # * <tt>:if_not_exists</tt> -
      #   Specifies if the column already exists to not try to re-add it. This will avoid
      #   duplicate column errors.
      #
      # Note: The precision is the total number of significant digits,
      # and the scale is the number of digits that can be stored following
      # the decimal point. For example, the number 123.45 has a precision of 5
      # and a scale of 2. A decimal with a precision of 5 and a scale of 2 can
      # range from -999.99 to 999.99.
      #
      # Please be aware of different RDBMS implementations behavior with
      # <tt>:decimal</tt> columns:
      # * The SQL standard says the default scale should be 0, <tt>:scale</tt> <=
      #   <tt>:precision</tt>, and makes no comments about the requirements of
      #   <tt>:precision</tt>.
      # * MySQL: <tt>:precision</tt> [1..65], <tt>:scale</tt> [0..30].
      #   Default is (10,0).
      # * PostgreSQL: <tt>:precision</tt> [1..infinity],
      #   <tt>:scale</tt> [0..infinity]. No default.
      # * SQLite3: No restrictions on <tt>:precision</tt> and <tt>:scale</tt>,
      #   but the maximum supported <tt>:precision</tt> is 16. No default.
      # * Oracle: <tt>:precision</tt> [1..38], <tt>:scale</tt> [-84..127].
      #   Default is (38,0).
      # * SqlServer: <tt>:precision</tt> [1..38], <tt>:scale</tt> [0..38].
      #   Default (38,0).
      #
      # == Examples
      #
      #  add_column(:users, :picture, :binary, limit: 2.megabytes)
      #  # ALTER TABLE "users" ADD "picture" blob(2097152)
      #
      #  add_column(:articles, :status, :string, limit: 20, default: 'draft', null: false)
      #  # ALTER TABLE "articles" ADD "status" varchar(20) DEFAULT 'draft' NOT NULL
      #
      #  add_column(:answers, :bill_gates_money, :decimal, precision: 15, scale: 2)
      #  # ALTER TABLE "answers" ADD "bill_gates_money" decimal(15,2)
      #
      #  add_column(:measurements, :sensor_reading, :decimal, precision: 30, scale: 20)
      #  # ALTER TABLE "measurements" ADD "sensor_reading" decimal(30,20)
      #
      #  # While :scale defaults to zero on most databases, it
      #  # probably wouldn't hurt to include it.
      #  add_column(:measurements, :huge_integer, :decimal, precision: 30)
      #  # ALTER TABLE "measurements" ADD "huge_integer" decimal(30)
      #
      #  # Defines a column that stores an array of a type.
      #  add_column(:users, :skills, :text, array: true)
      #  # ALTER TABLE "users" ADD "skills" text[]
      #
      #  # Defines a column with a database-specific type.
      #  add_column(:shapes, :triangle, 'polygon')
      #  # ALTER TABLE "shapes" ADD "triangle" polygon
      #
      #  # Ignores the method call if the column exists
      #  add_column(:shapes, :triangle, 'polygon', if_not_exists: true)
      def add_column(table_name, column_name, type, **options)
        add_column_def = build_add_column_definition(table_name, column_name, type, **options)
        return unless add_column_def

        execute schema_creation.accept(add_column_def)
      end

      def add_columns(table_name, *column_names, type:, **options) # :nodoc:
        column_names.each do |column_name|
          add_column(table_name, column_name, type, **options)
        end
      end

      # Builds an AlterTable object for adding a column to a table.
      #
      # This definition object contains information about the column that would be created
      # if the same arguments were passed to #add_column. See #add_column for information about
      # passing a +table_name+, +column_name+, +type+ and other options that can be passed.
      def build_add_column_definition(table_name, column_name, type, **options) # :nodoc:
        return if options[:if_not_exists] == true && column_exists?(table_name, column_name)

        if supports_datetime_with_precision?
          if type == :datetime && !options.key?(:precision)
            options[:precision] = 6
          end
        end

        alter_table = create_alter_table(table_name)
        alter_table.add_column(column_name, type, **options)
        alter_table
      end

      # Removes the given columns from the table definition.
      #
      #   remove_columns(:suppliers, :qualification, :experience)
      #
      # +type+ and other column options can be passed to make migration reversible.
      #
      #    remove_columns(:suppliers, :qualification, :experience, type: :string, null: false)
      def remove_columns(table_name, *column_names, type: nil, **options)
        if column_names.empty?
          raise ArgumentError.new("You must specify at least one column name. Example: remove_columns(:people, :first_name)")
        end

        remove_column_fragments = remove_columns_for_alter(table_name, *column_names, type: type, **options)
        execute "ALTER TABLE #{quote_table_name(table_name)} #{remove_column_fragments.join(', ')}"
      end

      # Removes the column from the table definition.
      #
      #   remove_column(:suppliers, :qualification)
      #
      # The +type+ and +options+ parameters will be ignored if present. It can be helpful
      # to provide these in a migration's +change+ method so it can be reverted.
      # In that case, +type+ and +options+ will be used by #add_column.
      # Depending on the database you're using, indexes using this column may be
      # automatically removed or modified to remove this column from the index.
      #
      # If the options provided include an +if_exists+ key, it will be used to check if the
      # column does not exist. This will silently ignore the migration rather than raising
      # if the column was already removed.
      #
      #   remove_column(:suppliers, :qualification, if_exists: true)
      def remove_column(table_name, column_name, type = nil, **options)
        return if options[:if_exists] == true && !column_exists?(table_name, column_name)

        execute "ALTER TABLE #{quote_table_name(table_name)} #{remove_column_for_alter(table_name, column_name, type, **options)}"
      end

      # Changes the column's definition according to the new options.
      # See TableDefinition#column for details of the options you can use.
      #
      #   change_column(:suppliers, :name, :string, limit: 80)
      #   change_column(:accounts, :description, :text)
      #
      def change_column(table_name, column_name, type, **options)
        raise NotImplementedError, "change_column is not implemented"
      end

      # Sets a new default value for a column:
      #
      #   change_column_default(:suppliers, :qualification, 'new')
      #   change_column_default(:accounts, :authorized, 1)
      #
      # Setting the default to +nil+ effectively drops the default:
      #
      #   change_column_default(:users, :email, nil)
      #
      # Passing a hash containing +:from+ and +:to+ will make this change
      # reversible in migration:
      #
      #   change_column_default(:posts, :state, from: nil, to: "draft")
      #
      def change_column_default(table_name, column_name, default_or_changes)
        raise NotImplementedError, "change_column_default is not implemented"
      end

      # Builds a ChangeColumnDefaultDefinition object.
      #
      # This definition object contains information about the column change that would occur
      # if the same arguments were passed to #change_column_default. See #change_column_default for
      # information about passing a +table_name+, +column_name+, +type+ and other options that can be passed.
      def build_change_column_default_definition(table_name, column_name, default_or_changes) # :nodoc:
        raise NotImplementedError, "build_change_column_default_definition is not implemented"
      end

      # Sets or removes a <tt>NOT NULL</tt> constraint on a column. The +null+ flag
      # indicates whether the value can be +NULL+. For example
      #
      #   change_column_null(:users, :nickname, false)
      #
      # says nicknames cannot be +NULL+ (adds the constraint), whereas
      #
      #   change_column_null(:users, :nickname, true)
      #
      # allows them to be +NULL+ (drops the constraint).
      #
      # The method accepts an optional fourth argument to replace existing
      # <tt>NULL</tt>s with some other value. Use that one when enabling the
      # constraint if needed, since otherwise those rows would not be valid.
      #
      # Please note the fourth argument does not set a column's default.
      def change_column_null(table_name, column_name, null, default = nil)
        raise NotImplementedError, "change_column_null is not implemented"
      end

      # Renames a column.
      #
      #   rename_column(:suppliers, :description, :name)
      #
      def rename_column(table_name, column_name, new_column_name)
        raise NotImplementedError, "rename_column is not implemented"
      end

      # Adds a new index to the table. +column_name+ can be a single Symbol, or
      # an Array of Symbols.
      #
      # The index will be named after the table and the column name(s), unless
      # you pass <tt>:name</tt> as an option.
      #
      # ====== Creating a simple index
      #
      #   add_index(:suppliers, :name)
      #
      # generates:
      #
      #   CREATE INDEX index_suppliers_on_name ON suppliers(name)
      #
      # ====== Creating a index which already exists
      #
      #   add_index(:suppliers, :name, if_not_exists: true)
      #
      # generates:
      #
      #   CREATE INDEX IF NOT EXISTS index_suppliers_on_name ON suppliers(name)
      #
      # Note: Not supported by MySQL.
      #
      # ====== Creating a unique index
      #
      #   add_index(:accounts, [:branch_id, :party_id], unique: true)
      #
      # generates:
      #
      #   CREATE UNIQUE INDEX index_accounts_on_branch_id_and_party_id ON accounts(branch_id, party_id)
      #
      # ====== Creating a named index
      #
      #   add_index(:accounts, [:branch_id, :party_id], unique: true, name: 'by_branch_party')
      #
      # generates:
      #
      #  CREATE UNIQUE INDEX by_branch_party ON accounts(branch_id, party_id)
      #
      # ====== Creating an index with specific key length
      #
      #   add_index(:accounts, :name, name: 'by_name', length: 10)
      #
      # generates:
      #
      #   CREATE INDEX by_name ON accounts(name(10))
      #
      # ====== Creating an index with specific key lengths for multiple keys
      #
      #   add_index(:accounts, [:name, :surname], name: 'by_name_surname', length: {name: 10, surname: 15})
      #
      # generates:
      #
      #   CREATE INDEX by_name_surname ON accounts(name(10), surname(15))
      #
      # Note: only supported by MySQL
      #
      # ====== Creating an index with a sort order (desc or asc, asc is the default)
      #
      #   add_index(:accounts, [:branch_id, :party_id, :surname], name: 'by_branch_desc_party', order: {branch_id: :desc, party_id: :asc})
      #
      # generates:
      #
      #   CREATE INDEX by_branch_desc_party ON accounts(branch_id DESC, party_id ASC, surname)
      #
      # Note: MySQL only supports index order from 8.0.1 onwards (earlier versions accepted the syntax but ignored it).
      #
      # ====== Creating a partial index
      #
      #   add_index(:accounts, [:branch_id, :party_id], unique: true, where: "active")
      #
      # generates:
      #
      #   CREATE UNIQUE INDEX index_accounts_on_branch_id_and_party_id ON accounts(branch_id, party_id) WHERE active
      #
      # Note: Partial indexes are only supported for PostgreSQL and SQLite.
      #
      # ====== Creating an index that includes additional columns
      #
      #   add_index(:accounts, :branch_id,  include: :party_id)
      #
      # generates:
      #
      #   CREATE INDEX index_accounts_on_branch_id ON accounts USING btree(branch_id) INCLUDE (party_id)
      #
      # Note: only supported by PostgreSQL.
      #
      # ====== Creating an index where NULLs are treated equally
      #
      #   add_index(:people, :last_name, nulls_not_distinct: true)
      #
      # generates:
      #
      #   CREATE INDEX index_people_on_last_name ON people (last_name) NULLS NOT DISTINCT
      #
      # Note: only supported by PostgreSQL version 15.0.0 and greater.
      #
      # ====== Creating an index with a specific method
      #
      #   add_index(:developers, :name, using: 'btree')
      #
      # generates:
      #
      #   CREATE INDEX index_developers_on_name ON developers USING btree (name) -- PostgreSQL
      #   CREATE INDEX index_developers_on_name USING btree ON developers (name) -- MySQL
      #
      # Note: only supported by PostgreSQL and MySQL
      #
      # ====== Creating an index with a specific operator class
      #
      #   add_index(:developers, :name, using: 'gist', opclass: :gist_trgm_ops)
      #   # CREATE INDEX developers_on_name ON developers USING gist (name gist_trgm_ops) -- PostgreSQL
      #
      #   add_index(:developers, [:name, :city], using: 'gist', opclass: { city: :gist_trgm_ops })
      #   # CREATE INDEX developers_on_name_and_city ON developers USING gist (name, city gist_trgm_ops) -- PostgreSQL
      #
      #   add_index(:developers, [:name, :city], using: 'gist', opclass: :gist_trgm_ops)
      #   # CREATE INDEX developers_on_name_and_city ON developers USING gist (name gist_trgm_ops, city gist_trgm_ops) -- PostgreSQL
      #
      # Note: only supported by PostgreSQL
      #
      # ====== Creating an index with a specific type
      #
      #   add_index(:developers, :name, type: :fulltext)
      #
      # generates:
      #
      #   CREATE FULLTEXT INDEX index_developers_on_name ON developers (name) -- MySQL
      #
      # Note: only supported by MySQL.
      #
      # ====== Creating an index with a specific algorithm
      #
      #  add_index(:developers, :name, algorithm: :concurrently)
      #  # CREATE INDEX CONCURRENTLY developers_on_name on developers (name) -- PostgreSQL
      #
      #  add_index(:developers, :name, algorithm: :inplace)
      #  # CREATE INDEX `index_developers_on_name` ON `developers` (`name`) ALGORITHM = INPLACE -- MySQL
      #
      # Note: only supported by PostgreSQL and MySQL.
      #
      # Concurrently adding an index is not supported in a transaction.
      #
      # For more information see the {"Transactional Migrations" section}[rdoc-ref:Migration].
      #
      # ====== Creating an index that is not used by queries
      #
      #   add_index(:developers, :name, enabled: false)
      #
      # generates:
      #
      #   CREATE INDEX index_developers_on_name ON developers (name) INVISIBLE -- MySQL
      #
      #   CREATE INDEX index_developers_on_name ON developers (name) IGNORED -- MariaDB
      #
      # Note: only supported by MySQL version 8.0.0 and greater, and MariaDB version 10.6.0 and greater.
      #
      def add_index(table_name, column_name, **options)
        create_index = build_create_index_definition(table_name, column_name, **options)
        execute schema_creation.accept(create_index)
      end

      # Builds a CreateIndexDefinition object.
      #
      # This definition object contains information about the index that would be created
      # if the same arguments were passed to #add_index. See #add_index for information about
      # passing a +table_name+, +column_name+, and other additional options that can be passed.
      def build_create_index_definition(table_name, column_name, **options) # :nodoc:
        index, algorithm, if_not_exists = add_index_options(table_name, column_name, **options)
        CreateIndexDefinition.new(index, algorithm, if_not_exists)
      end

      # Removes the given index from the table.
      #
      # Removes the index on +branch_id+ in the +accounts+ table if exactly one such index exists.
      #
      #   remove_index :accounts, :branch_id
      #
      # Removes the index on +branch_id+ in the +accounts+ table if exactly one such index exists.
      #
      #   remove_index :accounts, column: :branch_id
      #
      # Removes the index on +branch_id+ and +party_id+ in the +accounts+ table if exactly one such index exists.
      #
      #   remove_index :accounts, column: [:branch_id, :party_id]
      #
      # Removes the index named +by_branch_party+ in the +accounts+ table.
      #
      #   remove_index :accounts, name: :by_branch_party
      #
      # Removes the index on +branch_id+ named +by_branch_party+ in the +accounts+ table.
      #
      #   remove_index :accounts, :branch_id, name: :by_branch_party
      #
      # Checks if the index exists before trying to remove it. Will silently ignore indexes that
      # don't exist.
      #
      #   remove_index :accounts, if_exists: true
      #
      # Removes the index named +by_branch_party+ in the +accounts+ table +concurrently+.
      #
      #   remove_index :accounts, name: :by_branch_party, algorithm: :concurrently
      #
      # Note: only supported by PostgreSQL.
      #
      # Concurrently removing an index is not supported in a transaction.
      #
      # For more information see the {"Transactional Migrations" section}[rdoc-ref:Migration].
      def remove_index(table_name, column_name = nil, **options)
        return if options[:if_exists] && !index_exists?(table_name, column_name, **options)

        index_name = index_name_for_remove(table_name, column_name, options)

        execute "DROP INDEX #{quote_column_name(index_name)} ON #{quote_table_name(table_name)}"
      end

      # Renames an index.
      #
      # Rename the +index_people_on_last_name+ index to +index_users_on_last_name+:
      #
      #   rename_index :people, 'index_people_on_last_name', 'index_users_on_last_name'
      #
      def rename_index(table_name, old_name, new_name)
        old_name = old_name.to_s
        new_name = new_name.to_s
        validate_index_length!(table_name, new_name)

        # this is a naive implementation; some DBs may support this more efficiently (PostgreSQL, for instance)
        old_index_def = indexes(table_name).detect { |i| i.name == old_name }
        return unless old_index_def
        add_index(table_name, old_index_def.columns, name: new_name, unique: old_index_def.unique)
        remove_index(table_name, name: old_name)
      end

      def index_name(table_name, options) # :nodoc:
        if Hash === options
          if options[:column]
            if options[:_uses_legacy_index_name]
              "index_#{table_name}_on_#{Array(options[:column]) * '_and_'}"
            else
              generate_index_name(table_name, options[:column])
            end
          elsif options[:name]
            options[:name]
          else
            raise ArgumentError, "You must specify the index name"
          end
        else
          index_name(table_name, index_name_options(options))
        end
      end

      # Verifies the existence of an index with a given name.
      def index_name_exists?(table_name, index_name)
        index_name = index_name.to_s
        indexes(table_name).detect { |i| i.name == index_name }
      end

      # Adds a reference. The reference column is a bigint by default,
      # the <tt>:type</tt> option can be used to specify a different type.
      # Optionally adds a +_type+ column, if <tt>:polymorphic</tt> option is provided.
      #
      # The +options+ hash can include the following keys:
      # [<tt>:type</tt>]
      #   The reference column type. Defaults to +:bigint+.
      # [<tt>:index</tt>]
      #   Add an appropriate index. Defaults to true.
      #   See #add_index for usage of this option.
      # [<tt>:foreign_key</tt>]
      #   Add an appropriate foreign key constraint. Defaults to false, pass true
      #   to add. In case the join table can't be inferred from the association
      #   pass <tt>:to_table</tt> with the appropriate table name.
      # [<tt>:polymorphic</tt>]
      #   Whether an additional +_type+ column should be added. Defaults to false.
      # [<tt>:null</tt>]
      #   Whether the column allows nulls. Defaults to true.
      #
      # ====== Create a user_id bigint column without an index
      #
      #   add_reference(:products, :user, index: false)
      #
      # ====== Create a user_id string column
      #
      #   add_reference(:products, :user, type: :string)
      #
      # ====== Create supplier_id, supplier_type columns
      #
      #   add_reference(:products, :supplier, polymorphic: true)
      #
      # ====== Create a supplier_id column with a unique index
      #
      #   add_reference(:products, :supplier, index: { unique: true })
      #
      # ====== Create a supplier_id column with a named index
      #
      #   add_reference(:products, :supplier, index: { name: "my_supplier_index" })
      #
      # ====== Create a supplier_id column and appropriate foreign key
      #
      #   add_reference(:products, :supplier, foreign_key: true)
      #
      # ====== Create a supplier_id column and a foreign key to the firms table
      #
      #   add_reference(:products, :supplier, foreign_key: { to_table: :firms })
      #
      def add_reference(table_name, ref_name, **options)
        ReferenceDefinition.new(ref_name, **options).add(table_name, self)
      end
      alias :add_belongs_to :add_reference

      # Removes the reference(s). Also removes a +type+ column if one exists.
      #
      # ====== Remove the reference
      #
      #   remove_reference(:products, :user, index: false)
      #
      # ====== Remove polymorphic reference
      #
      #   remove_reference(:products, :supplier, polymorphic: true)
      #
      # ====== Remove the reference with a foreign key
      #
      #   remove_reference(:products, :user, foreign_key: true)
      #
      def remove_reference(table_name, ref_name, foreign_key: false, polymorphic: false, **options)
        conditional_options = options.slice(:if_exists, :if_not_exists)

        if foreign_key
          reference_name = Base.pluralize_table_names ? ref_name.to_s.pluralize : ref_name
          if foreign_key.is_a?(Hash)
            foreign_key_options = foreign_key.merge(conditional_options)
          else
            foreign_key_options = { to_table: reference_name, **conditional_options }
          end
          foreign_key_options[:column] ||= "#{ref_name}_id"
          remove_foreign_key(table_name, **foreign_key_options)
        end

        remove_column(table_name, "#{ref_name}_id", **conditional_options)
        remove_column(table_name, "#{ref_name}_type", **conditional_options) if polymorphic
      end
      alias :remove_belongs_to :remove_reference

      # Returns an array of foreign keys for the given table.
      # The foreign keys are represented as ForeignKeyDefinition objects.
      def foreign_keys(table_name)
        raise NotImplementedError, "foreign_keys is not implemented"
      end

      # Adds a new foreign key. +from_table+ is the table with the key column,
      # +to_table+ contains the referenced primary key.
      #
      # The foreign key will be named after the following pattern: <tt>fk_rails_<identifier></tt>.
      # +identifier+ is a 10 character long string which is deterministically generated from the
      # +from_table+ and +column+. A custom name can be specified with the <tt>:name</tt> option.
      #
      # ====== Creating a simple foreign key
      #
      #   add_foreign_key :articles, :authors
      #
      # generates:
      #
      #   ALTER TABLE "articles" ADD CONSTRAINT fk_rails_e74ce85cbc FOREIGN KEY ("author_id") REFERENCES "authors" ("id")
      #
      # ====== Creating a foreign key, ignoring method call if the foreign key exists
      #
      #  add_foreign_key(:articles, :authors, if_not_exists: true)
      #
      # ====== Creating a foreign key on a specific column
      #
      #   add_foreign_key :articles, :users, column: :author_id, primary_key: "lng_id"
      #
      # generates:
      #
      #   ALTER TABLE "articles" ADD CONSTRAINT fk_rails_58ca3d3a82 FOREIGN KEY ("author_id") REFERENCES "users" ("lng_id")
      #
      # ====== Creating a composite foreign key
      #
      #   Assuming "carts" table has "(shop_id, user_id)" as a primary key.
      #
      #   add_foreign_key :orders, :carts, primary_key: [:shop_id, :user_id]
      #
      # generates:
      #
      #   ALTER TABLE "orders" ADD CONSTRAINT fk_rails_6f5e4cb3a4 FOREIGN KEY ("cart_shop_id", "cart_user_id") REFERENCES "carts" ("shop_id", "user_id")
      #
      # ====== Creating a cascading foreign key
      #
      #   add_foreign_key :articles, :authors, on_delete: :cascade
      #
      # generates:
      #
      #   ALTER TABLE "articles" ADD CONSTRAINT fk_rails_e74ce85cbc FOREIGN KEY ("author_id") REFERENCES "authors" ("id") ON DELETE CASCADE
      #
      # The +options+ hash can include the following keys:
      # [<tt>:column</tt>]
      #   The foreign key column name on +from_table+. Defaults to <tt>to_table.singularize + "_id"</tt>.
      #   Pass an array to create a composite foreign key.
      # [<tt>:primary_key</tt>]
      #   The primary key column name on +to_table+. Defaults to +id+.
      #   Pass an array to create a composite foreign key.
      # [<tt>:name</tt>]
      #   The constraint name. Defaults to <tt>fk_rails_<identifier></tt>.
      # [<tt>:on_delete</tt>]
      #   Action that happens <tt>ON DELETE</tt>. Valid values are +:nullify+, +:cascade+, and +:restrict+
      # [<tt>:on_update</tt>]
      #   Action that happens <tt>ON UPDATE</tt>. Valid values are +:nullify+, +:cascade+, and +:restrict+
      # [<tt>:if_not_exists</tt>]
      #   Specifies if the foreign key already exists to not try to re-add it. This will avoid
      #   duplicate column errors.
      # [<tt>:validate</tt>]
      #   (PostgreSQL only) Specify whether or not the constraint should be validated. Defaults to +true+.
      # [<tt>:deferrable</tt>]
      #   (PostgreSQL only) Specify whether or not the foreign key should be deferrable. Valid values are booleans or
      #   +:deferred+ or +:immediate+ to specify the default behavior. Defaults to +false+.
      def add_foreign_key(from_table, to_table, **options)
        return unless use_foreign_keys?

        options = foreign_key_options(from_table, to_table, options)
        return if options[:if_not_exists] == true && foreign_key_exists?(from_table, to_table, **options.slice(:column, :primary_key))

        at = create_alter_table from_table
        at.add_foreign_key to_table, options

        execute schema_creation.accept(at)
      end

      # Removes the given foreign key from the table. Any option parameters provided
      # will be used to re-add the foreign key in case of a migration rollback.
      # It is recommended that you provide any options used when creating the foreign
      # key so that the migration can be reverted properly.
      #
      # Removes the foreign key on +accounts.branch_id+.
      #
      #   remove_foreign_key :accounts, :branches
      #
      # Removes the foreign key on +accounts.owner_id+.
      #
      #   remove_foreign_key :accounts, column: :owner_id
      #
      # Removes the foreign key on +accounts.owner_id+.
      #
      #   remove_foreign_key :accounts, to_table: :owners
      #
      # Removes the foreign key named +special_fk_name+ on the +accounts+ table.
      #
      #   remove_foreign_key :accounts, name: :special_fk_name
      #
      # Checks if the foreign key exists before trying to remove it. Will silently ignore indexes that
      # don't exist.
      #
      #   remove_foreign_key :accounts, :branches, if_exists: true
      #
      # The +options+ hash accepts the same keys as SchemaStatements#add_foreign_key
      # with an addition of
      # [<tt>:to_table</tt>]
      #   The name of the table that contains the referenced primary key.
      def remove_foreign_key(from_table, to_table = nil, **options)
        return unless use_foreign_keys?
        return if options.delete(:if_exists) == true && !foreign_key_exists?(from_table, to_table, **options.slice(:column))

        fk_name_to_delete = foreign_key_for!(from_table, to_table: to_table, **options).name

        at = create_alter_table from_table
        at.drop_foreign_key fk_name_to_delete

        execute schema_creation.accept(at)
      end

      # Checks to see if a foreign key exists on a table for a given foreign key definition.
      #
      #   # Checks to see if a foreign key exists.
      #   foreign_key_exists?(:accounts, :branches)
      #
      #   # Checks to see if a foreign key on a specified column exists.
      #   foreign_key_exists?(:accounts, column: :owner_id)
      #
      #   # Checks to see if a foreign key with a custom name exists.
      #   foreign_key_exists?(:accounts, name: "special_fk_name")
      #
      def foreign_key_exists?(from_table, to_table = nil, **options)
        foreign_key_for(from_table, to_table: to_table, **options).present?
      end

      def foreign_key_column_for(table_name, column_name) # :nodoc:
        name = strip_table_name_prefix_and_suffix(table_name)
        "#{name.singularize}_#{column_name}"
      end

      def foreign_key_options(from_table, to_table, options) # :nodoc:
        options = options.dup

        if options[:primary_key].is_a?(Array)
          options[:column] ||= options[:primary_key].map do |pk_column|
            foreign_key_column_for(to_table, pk_column)
          end
        else
          options[:column] ||= foreign_key_column_for(to_table, "id")
        end

        options[:name]   ||= foreign_key_name(from_table, options)

        if options[:column].is_a?(Array) || options[:primary_key].is_a?(Array)
          if Array(options[:primary_key]).size != Array(options[:column]).size
            raise ArgumentError, <<~MSG.squish
              For composite primary keys, specify :column and :primary_key, where
              :column must reference all the :primary_key columns from #{to_table.inspect}
            MSG
          end
        end

        options
      end

      # Returns an array of check constraints for the given table.
      # The check constraints are represented as CheckConstraintDefinition objects.
      def check_constraints(table_name)
        raise NotImplementedError
      end

      # Adds a new check constraint to the table. +expression+ is a String
      # representation of verifiable boolean condition.
      #
      #   add_check_constraint :products, "price > 0", name: "price_check"
      #
      # generates:
      #
      #   ALTER TABLE "products" ADD CONSTRAINT price_check CHECK (price > 0)
      #
      # The +options+ hash can include the following keys:
      # [<tt>:name</tt>]
      #   The constraint name. Defaults to <tt>chk_rails_<identifier></tt>.
      # [<tt>:if_not_exists</tt>]
      #   Silently ignore if the constraint already exists, rather than raise an error.
      # [<tt>:validate</tt>]
      #   (PostgreSQL only) Specify whether or not the constraint should be validated. Defaults to +true+.
      def add_check_constraint(table_name, expression, if_not_exists: false, **options)
        return unless supports_check_constraints?

        options = check_constraint_options(table_name, expression, options)
        return if if_not_exists && check_constraint_exists?(table_name, **options)

        at = create_alter_table(table_name)
        at.add_check_constraint(expression, options)

        execute schema_creation.accept(at)
      end

      def check_constraint_options(table_name, expression, options) # :nodoc:
        options = options.dup
        options[:name] ||= check_constraint_name(table_name, expression: expression, **options)
        options
      end

      # Removes the given check constraint from the table. Removing a check constraint
      # that does not exist will raise an error.
      #
      #   remove_check_constraint :products, name: "price_check"
      #
      # To silently ignore a non-existent check constraint rather than raise an error,
      # use the +if_exists+ option.
      #
      #   remove_check_constraint :products, name: "price_check", if_exists: true
      #
      # The +expression+ parameter will be ignored if present. It can be helpful
      # to provide this in a migration's +change+ method so it can be reverted.
      # In that case, +expression+ will be used by #add_check_constraint.
      def remove_check_constraint(table_name, expression = nil, if_exists: false, **options)
        return unless supports_check_constraints?

        return if if_exists && !check_constraint_exists?(table_name, **options)

        chk_name_to_delete = check_constraint_for!(table_name, expression: expression, **options).name

        at = create_alter_table(table_name)
        at.drop_check_constraint(chk_name_to_delete)

        execute schema_creation.accept(at)
      end

      # Checks to see if a check constraint exists on a table for a given check constraint definition.
      #
      #   check_constraint_exists?(:products, name: "price_check")
      #
      def check_constraint_exists?(table_name, **options)
        if !options.key?(:name) && !options.key?(:expression)
          raise ArgumentError, "At least one of :name or :expression must be supplied"
        end
        check_constraint_for(table_name, **options).present?
      end

      def remove_constraint(table_name, constraint_name) # :nodoc:
        at = create_alter_table(table_name)
        at.drop_constraint(constraint_name)

        execute schema_creation.accept(at)
      end

      def dump_schema_versions # :nodoc:
        versions = pool.schema_migration.versions
        insert_versions_sql(versions) if versions.any?
      end

      def internal_string_options_for_primary_key # :nodoc:
        { primary_key: true }
      end

      def assume_migrated_upto_version(version)
        version = version.to_i
        sm_table = quote_table_name(pool.schema_migration.table_name)

        migration_context = pool.migration_context
        migrated = migration_context.get_all_versions
        versions = migration_context.migrations.map(&:version)

        unless migrated.include?(version)
          execute "INSERT INTO #{sm_table} (version) VALUES (#{quote(version)})"
        end

        inserting = (versions - migrated).select { |v| v < version }
        if inserting.any?
          if (duplicate = inserting.detect { |v| inserting.count(v) > 1 })
            raise "Duplicate migration #{duplicate}. Please renumber your migrations to resolve the conflict."
          end
          execute insert_versions_sql(inserting)
        end
      end

      def type_to_sql(type, limit: nil, precision: nil, scale: nil, **) # :nodoc:
        type = type.to_sym if type
        if native = native_database_types[type]
          column_type_sql = (native.is_a?(Hash) ? native[:name] : native).dup

          if type == :decimal # ignore limit, use precision and scale
            scale ||= native[:scale]

            if precision ||= native[:precision]
              if scale
                column_type_sql << "(#{precision},#{scale})"
              else
                column_type_sql << "(#{precision})"
              end
            elsif scale
              raise ArgumentError, "Error adding decimal column: precision cannot be empty if scale is specified"
            end

          elsif [:datetime, :timestamp, :time, :interval].include?(type) && precision ||= native[:precision]
            if (0..6) === precision
              column_type_sql << "(#{precision})"
            else
              raise ArgumentError, "No #{native[:name]} type has precision of #{precision}. The allowed range of precision is from 0 to 6"
            end
          elsif (type != :primary_key) && (limit ||= native.is_a?(Hash) && native[:limit])
            column_type_sql << "(#{limit})"
          end

          column_type_sql
        else
          type.to_s
        end
      end

      # Given a set of columns and an ORDER BY clause, returns the columns for a SELECT DISTINCT.
      # PostgreSQL, MySQL, and Oracle override this for custom DISTINCT syntax - they
      # require the order columns appear in the SELECT.
      #
      #   columns_for_distinct("posts.id", ["posts.created_at desc"])
      #
      def columns_for_distinct(columns, orders) # :nodoc:
        columns
      end

      def distinct_relation_for_primary_key(relation) # :nodoc:
        primary_key_columns = Array(relation.primary_key).map do |column|
          visitor.compile(relation.table[column])
        end

        values = columns_for_distinct(
          primary_key_columns,
          relation.order_values
        )

        limited = relation.reselect(values).distinct!
        limited_ids = select_rows(limited.arel, "SQL").map do |results|
          results.last(Array(relation.primary_key).length) # ignores order values for MySQL and PostgreSQL
        end

        if limited_ids.empty?
          relation.none!
        else
          relation.where!(**Array(relation.primary_key).zip(limited_ids.transpose).to_h)
        end

        relation.limit_value = relation.offset_value = nil
        relation
      end

      # Adds timestamps (+created_at+ and +updated_at+) columns to +table_name+.
      # Additional options (like +:null+) are forwarded to #add_column.
      #
      #   add_timestamps(:suppliers, null: true)
      #
      def add_timestamps(table_name, **options)
        fragments = add_timestamps_for_alter(table_name, **options)
        execute "ALTER TABLE #{quote_table_name(table_name)} #{fragments.join(', ')}"
      end

      # Removes the timestamp columns (+created_at+ and +updated_at+) from the table definition.
      #
      #  remove_timestamps(:suppliers)
      #
      def remove_timestamps(table_name, **options)
        remove_columns table_name, :updated_at, :created_at
      end

      def update_table_definition(table_name, base) # :nodoc:
        Table.new(table_name, base)
      end

      def add_index_options(table_name, column_name, name: nil, if_not_exists: false, internal: false, **options) # :nodoc:
        options.assert_valid_keys(valid_index_options)

        column_names = index_column_names(column_name)

        index_name = name&.to_s
        index_name ||= index_name(table_name, column_names)

        validate_index_length!(table_name, index_name, internal)

        index = create_index_definition(
          table_name, index_name,
          options[:unique],
          column_names,
          lengths: options[:length] || {},
          orders: options[:order] || {},
          opclasses: options[:opclass] || {},
          where: options[:where],
          type: options[:type],
          using: options[:using],
          include: options[:include],
          nulls_not_distinct: options[:nulls_not_distinct],
          comment: options[:comment]
        )

        [index, index_algorithm(options[:algorithm]), if_not_exists]
      end

      def index_algorithm(algorithm) # :nodoc:
        index_algorithms.fetch(algorithm) do
          raise ArgumentError, "Algorithm must be one of the following: #{index_algorithms.keys.map(&:inspect).join(', ')}"
        end if algorithm
      end

      def quoted_columns_for_index(column_names, options) # :nodoc:
        quoted_columns = column_names.each_with_object({}) do |name, result|
          result[name.to_sym] = quote_column_name(name).dup
        end
        add_options_for_index_columns(quoted_columns, **options).values.join(", ")
      end

      def options_include_default?(options)
        options.include?(:default) && !(options[:null] == false && options[:default].nil?)
      end

      # Changes the comment for a table or removes it if +nil+.
      #
      # Passing a hash containing +:from+ and +:to+ will make this change
      # reversible in migration:
      #
      #   change_table_comment(:posts, from: "old_comment", to: "new_comment")
      def change_table_comment(table_name, comment_or_changes)
        raise NotImplementedError, "#{self.class} does not support changing table comments"
      end

      # Changes the comment for a column or removes it if +nil+.
      #
      # Passing a hash containing +:from+ and +:to+ will make this change
      # reversible in migration:
      #
      #   change_column_comment(:posts, :state, from: "old_comment", to: "new_comment")
      def change_column_comment(table_name, column_name, comment_or_changes)
        raise NotImplementedError, "#{self.class} does not support changing column comments"
      end

      # Enables an index to be used by queries.
      #
      #   enable_index(:users, :email)
      def enable_index(table_name, index_name)
        raise NotImplementedError, "#{self.class} does not support enabling indexes"
      end

      # Prevents an index from being used by queries.
      #
      #   disable_index(:users, :email)
      def disable_index(table_name, index_name)
        raise NotImplementedError, "#{self.class} does not support disabling indexes"
      end

      def create_schema_dumper(options) # :nodoc:
        SchemaDumper.create(self, options)
      end

      def use_foreign_keys?
        supports_foreign_keys? && foreign_keys_enabled?
      end

      # Returns an instance of SchemaCreation, which can be used to visit a schema definition
      # object and return DDL.
      def schema_creation # :nodoc:
        SchemaCreation.new(self)
      end

      def bulk_change_table(table_name, operations) # :nodoc:
        sql_fragments = []
        non_combinable_operations = []

        operations.each do |command, args|
          table, arguments = args.shift, args
          method = :"#{command}_for_alter"

          if respond_to?(method, true)
            sqls, procs = Array(send(method, table, *arguments)).partition { |v| v.is_a?(String) }
            sql_fragments.concat(sqls)
            non_combinable_operations.concat(procs)
          else
            execute "ALTER TABLE #{quote_table_name(table_name)} #{sql_fragments.join(", ")}" unless sql_fragments.empty?
            non_combinable_operations.each(&:call)
            sql_fragments = []
            non_combinable_operations = []
            send(command, table, *arguments)
          end
        end

        execute "ALTER TABLE #{quote_table_name(table_name)} #{sql_fragments.join(", ")}" unless sql_fragments.empty?
        non_combinable_operations.each(&:call)
      end

      def valid_table_definition_options # :nodoc:
        [:temporary, :if_not_exists, :options, :as, :comment, :charset, :collation]
      end

      def valid_column_definition_options # :nodoc:
        ColumnDefinition::OPTION_NAMES
      end

      def valid_primary_key_options # :nodoc:
        [:limit, :default, :precision]
      end

      # Returns the maximum length of an index name in bytes.
      def max_index_name_size
        62
      end

      private
        def generate_index_name(table_name, column)
          name = "index_#{table_name}_on_#{Array(column) * '_and_'}"
          return name if name.bytesize <= max_index_name_size

          # Fallback to short version, add hash to ensure uniqueness
          hashed_identifier = "_" + OpenSSL::Digest::SHA256.hexdigest(name).first(10)
          name = "idx_on_#{Array(column) * '_'}"

          short_limit = max_index_name_size - hashed_identifier.bytesize
          short_name = name.truncate_bytes(short_limit, omission: nil)

          "#{short_name}#{hashed_identifier}"
        end

        def validate_change_column_null_argument!(value)
          unless value == true || value == false
            raise ArgumentError, "change_column_null expects a boolean value (true for NULL, false for NOT NULL). Got: #{value.inspect}"
          end
        end

        def column_options_keys
          [:limit, :precision, :scale, :default, :null, :collation, :comment]
        end

        def add_index_sort_order(quoted_columns, **options)
          orders = options_for_index_columns(options[:order])
          quoted_columns.each do |name, column|
            column << " #{orders[name].upcase}" if orders[name].present?
          end
        end

        def valid_index_options
          [:unique, :length, :order, :opclass, :where, :type, :using, :comment, :algorithm, :include, :nulls_not_distinct]
        end

        def options_for_index_columns(options)
          if options.is_a?(Hash)
            options.symbolize_keys
          else
            Hash.new { |hash, column| hash[column] = options }
          end
        end

        # Overridden by the MySQL adapter for supporting index lengths and by
        # the PostgreSQL adapter for supporting operator classes.
        def add_options_for_index_columns(quoted_columns, **options)
          if supports_index_sort_order?
            quoted_columns = add_index_sort_order(quoted_columns, **options)
          end

          quoted_columns
        end

        def index_name_for_remove(table_name, column_name, options)
          return options[:name] if can_remove_index_by_name?(column_name, options)

          checks = []

          if !options.key?(:name) && expression_column_name?(column_name)
            options[:name] = index_name(table_name, column_name)
            column_names = []
          else
            column_names = index_column_names(column_name || options[:column])
          end

          checks << lambda { |i| i.name == options[:name].to_s } if options.key?(:name)

          if column_names.present? && !(options.key?(:name) && expression_column_name?(column_names))
            checks << lambda { |i| index_name(table_name, i.columns) == index_name(table_name, column_names) }
          end

          raise ArgumentError, "No name or columns specified" if checks.none?

          matching_indexes = indexes(table_name).select { |i| checks.all? { |check| check[i] } }

          if matching_indexes.count > 1
            raise ArgumentError, "Multiple indexes found on #{table_name} columns #{column_names}. " \
              "Specify an index name from #{matching_indexes.map(&:name).join(', ')}"
          elsif matching_indexes.none?
            raise ArgumentError, "No indexes found on #{table_name} with the options provided."
          else
            matching_indexes.first.name
          end
        end

        def rename_table_indexes(table_name, new_name, **options)
          indexes(new_name).each do |index|
            generated_index_name = index_name(table_name, column: index.columns, **options)
            if generated_index_name == index.name
              rename_index new_name, generated_index_name, index_name(new_name, column: index.columns, **options)
            end
          end
        end

        def rename_column_indexes(table_name, column_name, new_column_name)
          column_name, new_column_name = column_name.to_s, new_column_name.to_s
          indexes(table_name).each do |index|
            next unless index.columns.include?(new_column_name)
            old_columns = index.columns.dup
            old_columns[old_columns.index(new_column_name)] = column_name
            generated_index_name = index_name(table_name, column: old_columns)
            if generated_index_name == index.name
              rename_index table_name, generated_index_name, index_name(table_name, column: index.columns)
            end
          end
        end

        def create_table_definition(name, **options)
          TableDefinition.new(self, name, **options)
        end

        def create_index_definition(table_name, name, unique, columns, **options)
          IndexDefinition.new(table_name, name, unique, columns, **options)
        end

        def create_alter_table(name)
          AlterTable.new create_table_definition(name)
        end

        def validate_create_table_options!(options)
          unless options[:_skip_validate_options]
            options
              .except(:_uses_legacy_table_name, :_skip_validate_options)
              .assert_valid_keys(valid_table_definition_options, valid_primary_key_options)
          end
        end

        def fetch_type_metadata(sql_type)
          cast_type = lookup_cast_type(sql_type)
          SqlTypeMetadata.new(
            sql_type: sql_type,
            type: cast_type.type,
            limit: cast_type.limit,
            precision: cast_type.precision,
            scale: cast_type.scale,
          )
        end

        def index_column_names(column_names)
          if expression_column_name?(column_names)
            column_names
          else
            Array(column_names)
          end
        end

        def index_name_options(column_names)
          if expression_column_name?(column_names)
            column_names = column_names.scan(/\w+/).join("_")
          end

          { column: column_names }
        end

        # Try to identify whether the given column name is an expression
        def expression_column_name?(column_name)
          column_name.is_a?(String) && /\W/.match?(column_name)
        end

        def strip_table_name_prefix_and_suffix(table_name)
          prefix = Base.table_name_prefix
          suffix = Base.table_name_suffix
          table_name.to_s =~ /#{prefix}(.+)#{suffix}/ ? $1 : table_name.to_s
        end

        def foreign_key_name(table_name, options)
          options.fetch(:name) do
            columns = Array(options.fetch(:column)).map(&:to_s)
            identifier = "#{table_name}_#{columns * '_and_'}_fk"
            hashed_identifier = OpenSSL::Digest::SHA256.hexdigest(identifier).first(10)

            "fk_rails_#{hashed_identifier}"
          end
        end

        def foreign_key_for(from_table, **options)
          return unless use_foreign_keys?

          keys = foreign_keys(from_table)

          if options[:_skip_column_match]
            return keys.find { |fk| fk.defined_for?(**options) }
          end

          if options[:column].nil?
            default_column = foreign_key_column_for(options[:to_table], "id")
            matches = keys.select { |fk| fk.column == default_column }
            keys = matches if matches.any?
          end

          keys.find { |fk| fk.defined_for?(**options) }
        end

        def foreign_key_for!(from_table, to_table: nil, **options)
          foreign_key_for(from_table, to_table: to_table, **options) ||
            raise(ArgumentError, "Table '#{from_table}' has no foreign key for #{to_table || options}")
        end

        def extract_foreign_key_action(specifier)
          case specifier
          when "CASCADE"; :cascade
          when "SET NULL"; :nullify
          when "RESTRICT"; :restrict
          end
        end

        def foreign_keys_enabled?
          @config.fetch(:foreign_keys, true)
        end

        def check_constraint_name(table_name, **options)
          options.fetch(:name) do
            expression = options.fetch(:expression)
            identifier = "#{table_name}_#{expression}_chk"
            hashed_identifier = OpenSSL::Digest::SHA256.hexdigest(identifier).first(10)

            "chk_rails_#{hashed_identifier}"
          end
        end

        def check_constraint_for(table_name, **options)
          return unless supports_check_constraints?
          chk_name = check_constraint_name(table_name, **options)
          check_constraints(table_name).detect { |chk| chk.defined_for?(name: chk_name, **options) }
        end

        def check_constraint_for!(table_name, expression: nil, **options)
          check_constraint_for(table_name, expression: expression, **options) ||
            raise(ArgumentError, "Table '#{table_name}' has no check constraint for #{expression || options}")
        end

        def validate_index_length!(table_name, new_name, internal = false)
          if new_name.length > index_name_length
            raise ArgumentError, <<~MSG.squish
              Index name '#{new_name}' on table '#{table_name}' is too long (#{new_name.length} characters); the limit
              is #{index_name_length} characters
            MSG
          end
        end

        def validate_table_length!(table_name)
          if table_name.length > table_name_length
            raise ArgumentError, <<~MSG.squish
              Table name '#{table_name}' is too long (#{table_name.length} characters); the limit is
              #{table_name_length} characters
            MSG
          end
        end

        def extract_new_default_value(default_or_changes)
          if default_or_changes.is_a?(Hash) && default_or_changes.has_key?(:from) && default_or_changes.has_key?(:to)
            default_or_changes[:to]
          else
            default_or_changes
          end
        end
        alias :extract_new_comment_value :extract_new_default_value

        def can_remove_index_by_name?(column_name, options)
          column_name.nil? && options.key?(:name) && options.except(:name, :algorithm).empty?
        end

        def reference_name_for_table(table_name)
          table_name.to_s.singularize
        end

        def add_column_for_alter(table_name, column_name, type, **options)
          td = create_table_definition(table_name)
          cd = td.new_column_definition(column_name, type, **options)
          schema_creation.accept(AddColumnDefinition.new(cd))
        end

        def change_column_default_for_alter(table_name, column_name, default_or_changes)
          cd = build_change_column_default_definition(table_name, column_name, default_or_changes)
          schema_creation.accept(cd)
        end

        def rename_column_sql(table_name, column_name, new_column_name)
          "RENAME COLUMN #{quote_column_name(column_name)} TO #{quote_column_name(new_column_name)}"
        end

        def remove_column_for_alter(table_name, column_name, type = nil, **options)
          "DROP COLUMN #{quote_column_name(column_name)}"
        end

        def remove_columns_for_alter(table_name, *column_names, **options)
          column_names.map { |column_name| remove_column_for_alter(table_name, column_name) }
        end

        def add_timestamps_for_alter(table_name, **options)
          options[:null] = false if options[:null].nil?

          if !options.key?(:precision) && supports_datetime_with_precision?
            options[:precision] = 6
          end

          [
            add_column_for_alter(table_name, :created_at, :datetime, **options),
            add_column_for_alter(table_name, :updated_at, :datetime, **options)
          ]
        end

        def remove_timestamps_for_alter(table_name, **options)
          remove_columns_for_alter(table_name, :updated_at, :created_at)
        end

        def insert_versions_sql(versions)
          versions_formatter = ActiveRecord.schema_versions_formatter.new(self)
          versions_formatter.format(versions)
        end

        def data_source_sql(name = nil, type: nil)
          raise NotImplementedError
        end

        def quoted_scope(name = nil, type: nil)
          raise NotImplementedError
        end
    end
  end
end
