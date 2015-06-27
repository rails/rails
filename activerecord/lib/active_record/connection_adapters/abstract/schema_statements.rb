require 'active_record/migration/join_table'
require 'active_support/core_ext/string/access'
require 'digest'

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

      # Truncates a table alias according to the limits of the current adapter.
      def table_alias_for(table_name)
        table_name[0...table_alias_length].tr('.', '_')
      end

      # Checks to see if the table +table_name+ exists on the database.
      #
      #   table_exists?(:developers)
      #
      def table_exists?(table_name)
        tables.include?(table_name.to_s)
      end

      # Returns an array of indexes for the given table.
      # def indexes(table_name, name = nil) end

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
      def index_exists?(table_name, column_name, options = {})
        column_names = Array(column_name).map(&:to_s)
        index_name = options.key?(:name) ? options[:name].to_s : index_name(table_name, column: column_names)
        checks = []
        checks << lambda { |i| i.name == index_name }
        checks << lambda { |i| i.columns == column_names }
        checks << lambda { |i| i.unique } if options[:unique]

        indexes(table_name).any? { |i| checks.all? { |check| check[i] } }
      end

      # Returns an array of Column objects for the table specified by +table_name+.
      # See the concrete implementation for details on the expected parameter values.
      def columns(table_name) end

      # Checks to see if a column exists in a given table.
      #
      #   # Check a column exists
      #   column_exists?(:suppliers, :name)
      #
      #   # Check a column exists of a particular type
      #   column_exists?(:suppliers, :name, :string)
      #
      #   # Check a column exists with a specific definition
      #   column_exists?(:suppliers, :name, :string, limit: 100)
      #   column_exists?(:suppliers, :name, :string, default: 'default')
      #   column_exists?(:suppliers, :name, :string, null: false)
      #   column_exists?(:suppliers, :tax, :decimal, precision: 8, scale: 2)
      #
      def column_exists?(table_name, column_name, type = nil, options = {})
        column_name = column_name.to_s
        columns(table_name).any?{ |c| c.name == column_name &&
                                      (!type                     || c.type == type) &&
                                      (!options.key?(:limit)     || c.limit == options[:limit]) &&
                                      (!options.key?(:precision) || c.precision == options[:precision]) &&
                                      (!options.key?(:scale)     || c.scale == options[:scale]) &&
                                      (!options.key?(:default)   || c.default == options[:default]) &&
                                      (!options.key?(:null)      || c.null == options[:null]) }
      end

      # Creates a new table with the name +table_name+. +table_name+ may either
      # be a String or a Symbol.
      #
      # There are two ways to work with +create_table+. You can use the block
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
      #   Join tables for +has_and_belongs_to_many+ should set it to false.
      # [<tt>:primary_key</tt>]
      #   The name of the primary key, if one is to be added automatically.
      #   Defaults to +id+. If <tt>:id</tt> is false this option is ignored.
      #
      #   Note that Active Record models will automatically detect their
      #   primary key. This can be avoided by using +self.primary_key=+ on the model
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
      # [<tt>:as</tt>]
      #   SQL to use to generate the table. When this option is used, the block is
      #   ignored, as are the <tt>:id</tt> and <tt>:primary_key</tt> options.
      #
      # ====== Add a backend specific option to the generated SQL (MySQL)
      #
      #   create_table(:suppliers, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8')
      #
      # generates:
      #
      #   CREATE TABLE suppliers (
      #     id int(11) DEFAULT NULL auto_increment PRIMARY KEY
      #   ) ENGINE=InnoDB DEFAULT CHARSET=utf8
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
      #     guid int(11) DEFAULT NULL auto_increment PRIMARY KEY,
      #     name varchar(80)
      #   )
      #
      # ====== Do not add a primary key column
      #
      #   create_table(:categories_suppliers, id: false) do |t|
      #     t.column :category_id, :integer
      #     t.column :supplier_id, :integer
      #   end
      #
      # generates:
      #
      #   CREATE TABLE categories_suppliers (
      #     category_id int,
      #     supplier_id int
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
      def create_table(table_name, options = {})
        td = create_table_definition table_name, options[:temporary], options[:options], options[:as]

        if options[:id] != false && !options[:as]
          pk = options.fetch(:primary_key) do
            Base.get_primary_key table_name.to_s.singularize
          end

          td.primary_key pk, options.fetch(:id, :primary_key), options
        end

        yield td if block_given?

        if options[:force] && table_exists?(table_name)
          drop_table(table_name, options)
        end

        result = execute schema_creation.accept td

        unless supports_indexes_in_create?
          td.indexes.each_pair do |column_name, index_options|
            add_index(table_name, column_name, index_options)
          end
        end

        td.foreign_keys.each_pair do |other_table_name, foreign_key_options|
          add_foreign_key(table_name, other_table_name, foreign_key_options)
        end

        result
      end

      # Creates a new join table with the name created using the lexical order of the first two
      # arguments. These arguments can be a String or a Symbol.
      #
      #   # Creates a table called 'assemblies_parts' with no id.
      #   create_join_table(:assemblies, :parts)
      #
      # You can pass a +options+ hash can include the following keys:
      # [<tt>:table_name</tt>]
      #   Sets the table name overriding the default
      # [<tt>:column_options</tt>]
      #   Any extra options you want appended to the columns definition.
      # [<tt>:options</tt>]
      #   Any extra options you want appended to the table definition.
      # [<tt>:temporary</tt>]
      #   Make a temporary table.
      # [<tt>:force</tt>]
      #   Set to true to drop the table before creating it.
      #   Defaults to false.
      #
      # Note that +create_join_table+ does not create any indices by default; you can use
      # its block form to do so yourself:
      #
      #   create_join_table :products, :categories do |t|
      #     t.index :product_id
      #     t.index :category_id
      #   end
      #
      # ====== Add a backend specific option to the generated SQL (MySQL)
      #
      #   create_join_table(:assemblies, :parts, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8')
      #
      # generates:
      #
      #   CREATE TABLE assemblies_parts (
      #     assembly_id int NOT NULL,
      #     part_id int NOT NULL,
      #   ) ENGINE=InnoDB DEFAULT CHARSET=utf8
      #
      def create_join_table(table_1, table_2, options = {})
        join_table_name = find_join_table_name(table_1, table_2, options)

        column_options = options.delete(:column_options) || {}
        column_options.reverse_merge!(null: false)

        t1_column, t2_column = [table_1, table_2].map{ |t| t.to_s.singularize.foreign_key }

        create_table(join_table_name, options.merge!(id: false)) do |td|
          td.integer t1_column, column_options
          td.integer t2_column, column_options
          yield td if block_given?
        end
      end

      # Drops the join table specified by the given arguments.
      # See +create_join_table+ for details.
      #
      # Although this command ignores the block if one is given, it can be helpful
      # to provide one in a migration's +change+ method so it can be reverted.
      # In that case, the block will be used by create_join_table.
      def drop_join_table(table_1, table_2, options = {})
        join_table_name = find_join_table_name(table_1, table_2, options)
        drop_table(join_table_name)
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
      #     ALTER TABLE `users` ADD COLUMN age INT(11), ADD COLUMN birthdate DATETIME ...
      #
      #   Defaults to false.
      #
      # ====== Add a column
      #
      #   change_table(:suppliers) do |t|
      #     t.column :name, :string, limit: 60
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
      # Creates a <tt>company_id(integer)</tt> column.
      #
      # ====== Add a polymorphic foreign key column
      #
      #  change_table(:suppliers) do |t|
      #    t.belongs_to :company, polymorphic: true
      #  end
      #
      # Creates <tt>company_type(varchar)</tt> and <tt>company_id(integer)</tt> columns.
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
      # See also Table for details on all of the various column transformation.
      def change_table(table_name, options = {})
        if supports_bulk_alter? && options[:bulk]
          recorder = ActiveRecord::Migration::CommandRecorder.new(self)
          yield update_table_definition(table_name, recorder)
          bulk_change_table(table_name, recorder.commands)
        else
          yield update_table_definition(table_name, self)
        end
      end

      # Renames a table.
      #
      #   rename_table('octopuses', 'octopi')
      #
      def rename_table(table_name, new_name)
        raise NotImplementedError, "rename_table is not implemented"
      end

      # Drops a table from the database.
      #
      # [<tt>:force</tt>]
      #   Set to +:cascade+ to drop dependent objects as well.
      #   Defaults to false.
      #
      # Although this command ignores most +options+ and the block if one is given,
      # it can be helpful to provide these in a migration's +change+ method so it can be reverted.
      # In that case, +options+ and the block will be used by create_table.
      def drop_table(table_name, options = {})
        execute "DROP TABLE #{quote_table_name(table_name)}"
      end

      # Adds a new column to the named table.
      # See TableDefinition#column for details of the options you can use.
      def add_column(table_name, column_name, type, options = {})
        at = create_alter_table table_name
        at.add_column(column_name, type, options)
        execute schema_creation.accept at
      end

      # Removes the given columns from the table definition.
      #
      #   remove_columns(:suppliers, :qualification, :experience)
      #
      def remove_columns(table_name, *column_names)
        raise ArgumentError.new("You must specify at least one column name. Example: remove_columns(:people, :first_name)") if column_names.empty?
        column_names.each do |column_name|
          remove_column(table_name, column_name)
        end
      end

      # Removes the column from the table definition.
      #
      #   remove_column(:suppliers, :qualification)
      #
      # The +type+ and +options+ parameters will be ignored if present. It can be helpful
      # to provide these in a migration's +change+ method so it can be reverted.
      # In that case, +type+ and +options+ will be used by add_column.
      def remove_column(table_name, column_name, type = nil, options = {})
        execute "ALTER TABLE #{quote_table_name(table_name)} DROP #{quote_column_name(column_name)}"
      end

      # Changes the column's definition according to the new options.
      # See TableDefinition#column for details of the options you can use.
      #
      #   change_column(:suppliers, :name, :string, limit: 80)
      #   change_column(:accounts, :description, :text)
      #
      def change_column(table_name, column_name, type, options = {})
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
      def change_column_default(table_name, column_name, default)
        raise NotImplementedError, "change_column_default is not implemented"
      end

      # Sets or removes a +NOT NULL+ constraint on a column. The +null+ flag
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
      # +NULL+s with some other value. Use that one when enabling the
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
      #   CREATE INDEX suppliers_name_index ON suppliers(name)
      #
      # ====== Creating a unique index
      #
      #   add_index(:accounts, [:branch_id, :party_id], unique: true)
      #
      # generates:
      #
      #   CREATE UNIQUE INDEX accounts_branch_id_party_id_index ON accounts(branch_id, party_id)
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
      #   add_index(:accounts, [:name, :surname], name: 'by_name_surname', length: {name: 10, surname: 15})
      #
      # generates:
      #
      #   CREATE INDEX by_name_surname ON accounts(name(10), surname(15))
      #
      # Note: SQLite doesn't support index length.
      #
      # ====== Creating an index with a sort order (desc or asc, asc is the default)
      #
      #   add_index(:accounts, [:branch_id, :party_id, :surname], order: {branch_id: :desc, party_id: :asc})
      #
      # generates:
      #
      #   CREATE INDEX by_branch_desc_party ON accounts(branch_id DESC, party_id ASC, surname)
      #
      # Note: MySQL doesn't yet support index order (it accepts the syntax but ignores it).
      #
      # ====== Creating a partial index
      #
      #   add_index(:accounts, [:branch_id, :party_id], unique: true, where: "active")
      #
      # generates:
      #
      #   CREATE UNIQUE INDEX index_accounts_on_branch_id_and_party_id ON accounts(branch_id, party_id) WHERE active
      #
      # Note: Partial indexes are only supported for PostgreSQL and SQLite 3.8.0+.
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
      # ====== Creating an index with a specific type
      #
      #   add_index(:developers, :name, type: :fulltext)
      #
      # generates:
      #
      #   CREATE FULLTEXT INDEX index_developers_on_name ON developers (name) -- MySQL
      #
      # Note: only supported by MySQL. Supported: <tt>:fulltext</tt> and <tt>:spatial</tt> on MyISAM tables.
      def add_index(table_name, column_name, options = {})
        index_name, index_type, index_columns, index_options = add_index_options(table_name, column_name, options)
        execute "CREATE #{index_type} INDEX #{quote_column_name(index_name)} ON #{quote_table_name(table_name)} (#{index_columns})#{index_options}"
      end

      # Removes the given index from the table.
      #
      # Removes the +index_accounts_on_column+ in the +accounts+ table.
      #
      #   remove_index :accounts, :column
      #
      # Removes the index named +index_accounts_on_branch_id+ in the +accounts+ table.
      #
      #   remove_index :accounts, column: :branch_id
      #
      # Removes the index named +index_accounts_on_branch_id_and_party_id+ in the +accounts+ table.
      #
      #   remove_index :accounts, column: [:branch_id, :party_id]
      #
      # Removes the index named +by_branch_party+ in the +accounts+ table.
      #
      #   remove_index :accounts, name: :by_branch_party
      #
      def remove_index(table_name, options = {})
        remove_index!(table_name, index_name_for_remove(table_name, options))
      end

      def remove_index!(table_name, index_name) #:nodoc:
        execute "DROP INDEX #{quote_column_name(index_name)} ON #{quote_table_name(table_name)}"
      end

      # Renames an index.
      #
      # Rename the +index_people_on_last_name+ index to +index_users_on_last_name+:
      #
      #   rename_index :people, 'index_people_on_last_name', 'index_users_on_last_name'
      #
      def rename_index(table_name, old_name, new_name)
        validate_index_length!(table_name, new_name)

        # this is a naive implementation; some DBs may support this more efficiently (Postgres, for instance)
        old_index_def = indexes(table_name).detect { |i| i.name == old_name }
        return unless old_index_def
        add_index(table_name, old_index_def.columns, name: new_name, unique: old_index_def.unique)
        remove_index(table_name, name: old_name)
      end

      def index_name(table_name, options) #:nodoc:
        if Hash === options
          if options[:column]
            "index_#{table_name}_on_#{Array(options[:column]) * '_and_'}"
          elsif options[:name]
            options[:name]
          else
            raise ArgumentError, "You must specify the index name"
          end
        else
          index_name(table_name, :column => options)
        end
      end

      # Verifies the existence of an index with a given name.
      #
      # The default argument is returned if the underlying implementation does not define the indexes method,
      # as there's no way to determine the correct answer in that case.
      def index_name_exists?(table_name, index_name, default)
        return default unless respond_to?(:indexes)
        index_name = index_name.to_s
        indexes(table_name).detect { |i| i.name == index_name }
      end

      # Adds a reference. The reference column is an integer by default,
      # the <tt>:type</tt> option can be used to specify a different type.
      # Optionally adds a +_type+ column, if <tt>:polymorphic</tt> option is provided.
      # <tt>add_reference</tt> and <tt>add_belongs_to</tt> are acceptable.
      #
      # The +options+ hash can include the following keys:
      # [<tt>:type</tt>]
      #   The reference column type. Defaults to +:integer+.
      # [<tt>:index</tt>]
      #   Add an appropriate index. Defaults to false.
      # [<tt>:foreign_key</tt>]
      #   Add an appropriate foreign key. Defaults to false.
      # [<tt>:polymorphic</tt>]
      #   Wether an additional +_type+ column should be added. Defaults to false.
      #
      # ====== Create a user_id integer column
      #
      #   add_reference(:products, :user)
      #
      # ====== Create a user_id string column
      #
      #   add_reference(:products, :user, type: :string)
      #
      # ====== Create supplier_id, supplier_type columns and appropriate index
      #
      #   add_reference(:products, :supplier, polymorphic: true, index: true)
      #
      def add_reference(table_name, ref_name, options = {})
        polymorphic = options.delete(:polymorphic)
        index_options = options.delete(:index)
        type = options.delete(:type) || :integer
        foreign_key_options = options.delete(:foreign_key)

        if polymorphic && foreign_key_options
          raise ArgumentError, "Cannot add a foreign key to a polymorphic relation"
        end

        add_column(table_name, "#{ref_name}_id", type, options)
        add_column(table_name, "#{ref_name}_type", :string, polymorphic.is_a?(Hash) ? polymorphic : options) if polymorphic
        add_index(table_name, polymorphic ? %w[type id].map{ |t| "#{ref_name}_#{t}" } : "#{ref_name}_id", index_options.is_a?(Hash) ? index_options : {}) if index_options
        if foreign_key_options
          to_table = Base.pluralize_table_names ? ref_name.to_s.pluralize : ref_name
          add_foreign_key(table_name, to_table, foreign_key_options.is_a?(Hash) ? foreign_key_options : {})
        end
      end
      alias :add_belongs_to :add_reference

      # Removes the reference(s). Also removes a +type+ column if one exists.
      # <tt>remove_reference</tt>, <tt>remove_references</tt> and <tt>remove_belongs_to</tt> are acceptable.
      #
      # ====== Remove the reference
      #
      #   remove_reference(:products, :user, index: true)
      #
      # ====== Remove polymorphic reference
      #
      #   remove_reference(:products, :supplier, polymorphic: true)
      #
      # ====== Remove the reference with a foreign key
      #
      #   remove_reference(:products, :user, index: true, foreign_key: true)
      #
      def remove_reference(table_name, ref_name, options = {})
        if options[:foreign_key]
          to_table = Base.pluralize_table_names ? ref_name.to_s.pluralize : ref_name
          remove_foreign_key(table_name, to_table)
        end

        remove_column(table_name, "#{ref_name}_id")
        remove_column(table_name, "#{ref_name}_type") if options[:polymorphic]
      end
      alias :remove_belongs_to :remove_reference

      # Returns an array of foreign keys for the given table.
      # The foreign keys are represented as +ForeignKeyDefinition+ objects.
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
      #   ALTER TABLE "articles" ADD CONSTRAINT articles_author_id_fk FOREIGN KEY ("author_id") REFERENCES "authors" ("id")
      #
      # ====== Creating a foreign key on a specific column
      #
      #   add_foreign_key :articles, :users, column: :author_id, primary_key: :lng_id
      #
      # generates:
      #
      #   ALTER TABLE "articles" ADD CONSTRAINT fk_rails_58ca3d3a82 FOREIGN KEY ("author_id") REFERENCES "users" ("lng_id")
      #
      # ====== Creating a cascading foreign key
      #
      #   add_foreign_key :articles, :authors, on_delete: :cascade
      #
      # generates:
      #
      #   ALTER TABLE "articles" ADD CONSTRAINT articles_author_id_fk FOREIGN KEY ("author_id") REFERENCES "authors" ("id") ON DELETE CASCADE
      #
      # The +options+ hash can include the following keys:
      # [<tt>:column</tt>]
      #   The foreign key column name on +from_table+. Defaults to <tt>to_table.singularize + "_id"</tt>
      # [<tt>:primary_key</tt>]
      #   The primary key column name on +to_table+. Defaults to +id+.
      # [<tt>:name</tt>]
      #   The constraint name. Defaults to <tt>fk_rails_<identifier></tt>.
      # [<tt>:on_delete</tt>]
      #   Action that happens <tt>ON DELETE</tt>. Valid values are +:nullify+, +:cascade:+ and +:restrict+
      # [<tt>:on_update</tt>]
      #   Action that happens <tt>ON UPDATE</tt>. Valid values are +:nullify+, +:cascade:+ and +:restrict+
      def add_foreign_key(from_table, to_table, options = {})
        return unless supports_foreign_keys?

        options[:column] ||= foreign_key_column_for(to_table)

        options = {
          column: options[:column],
          primary_key: options[:primary_key],
          name: foreign_key_name(from_table, options),
          on_delete: options[:on_delete],
          on_update: options[:on_update]
        }
        at = create_alter_table from_table
        at.add_foreign_key to_table, options

        execute schema_creation.accept(at)
      end

      # Removes the given foreign key from the table.
      #
      # Removes the foreign key on +accounts.branch_id+.
      #
      #   remove_foreign_key :accounts, :branches
      #
      # Removes the foreign key on +accounts.owner_id+.
      #
      #   remove_foreign_key :accounts, column: :owner_id
      #
      # Removes the foreign key named +special_fk_name+ on the +accounts+ table.
      #
      #   remove_foreign_key :accounts, name: :special_fk_name
      #
      def remove_foreign_key(from_table, options_or_to_table = {})
        return unless supports_foreign_keys?

        if options_or_to_table.is_a?(Hash)
          options = options_or_to_table
        else
          options = { column: foreign_key_column_for(options_or_to_table) }
        end

        fk_name_to_delete = options.fetch(:name) do
          fk_to_delete = foreign_keys(from_table).detect {|fk| fk.column == options[:column].to_s }

          if fk_to_delete
            fk_to_delete.name
          else
            raise ArgumentError, "Table '#{from_table}' has no foreign key on column '#{options[:column]}'"
          end
        end

        at = create_alter_table from_table
        at.drop_foreign_key fk_name_to_delete

        execute schema_creation.accept(at)
      end

      def foreign_key_column_for(table_name) # :nodoc:
        prefix = Base.table_name_prefix
        suffix = Base.table_name_suffix
        name = table_name.to_s =~ /#{prefix}(.+)#{suffix}/ ? $1 : table_name.to_s
        "#{name.singularize}_id"
      end

      def dump_schema_information #:nodoc:
        sm_table = ActiveRecord::Migrator.schema_migrations_table_name

        ActiveRecord::SchemaMigration.order('version').map { |sm|
          "INSERT INTO #{sm_table} (version) VALUES ('#{sm.version}');"
        }.join "\n\n"
      end

      # Should not be called normally, but this operation is non-destructive.
      # The migrations module handles this automatically.
      def initialize_schema_migrations_table
        ActiveRecord::SchemaMigration.create_table
      end

      def assume_migrated_upto_version(version, migrations_paths = ActiveRecord::Migrator.migrations_paths)
        migrations_paths = Array(migrations_paths)
        version = version.to_i
        sm_table = quote_table_name(ActiveRecord::Migrator.schema_migrations_table_name)

        migrated = select_values("SELECT version FROM #{sm_table}").map { |v| v.to_i }
        paths = migrations_paths.map {|p| "#{p}/[0-9]*_*.rb" }
        versions = Dir[*paths].map do |filename|
          filename.split('/').last.split('_').first.to_i
        end

        unless migrated.include?(version)
          execute "INSERT INTO #{sm_table} (version) VALUES ('#{version}')"
        end

        inserted = Set.new
        (versions - migrated).each do |v|
          if inserted.include?(v)
            raise "Duplicate migration #{v}. Please renumber your migrations to resolve the conflict."
          elsif v < version
            execute "INSERT INTO #{sm_table} (version) VALUES ('#{v}')"
            inserted << v
          end
        end
      end

      def type_to_sql(type, limit = nil, precision = nil, scale = nil) #:nodoc:
        if native = native_database_types[type.to_sym]
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

          elsif (type != :primary_key) && (limit ||= native.is_a?(Hash) && native[:limit])
            column_type_sql << "(#{limit})"
          end

          column_type_sql
        else
          type.to_s
        end
      end

      # Given a set of columns and an ORDER BY clause, returns the columns for a SELECT DISTINCT.
      # Both PostgreSQL and Oracle overrides this for custom DISTINCT syntax - they
      # require the order columns appear in the SELECT.
      #
      #   columns_for_distinct("posts.id", ["posts.created_at desc"])
      def columns_for_distinct(columns, orders) #:nodoc:
        columns
      end

      include TimestampDefaultDeprecation
      # Adds timestamps (+created_at+ and +updated_at+) columns to +table_name+.
      # Additional options (like <tt>null: false</tt>) are forwarded to #add_column.
      #
      #   add_timestamps(:suppliers, null: false)
      #
      def add_timestamps(table_name, options = {})
        emit_warning_if_null_unspecified(:add_timestamps, options)
        add_column table_name, :created_at, :datetime, options
        add_column table_name, :updated_at, :datetime, options
      end

      # Removes the timestamp columns (+created_at+ and +updated_at+) from the table definition.
      #
      #  remove_timestamps(:suppliers)
      #
      def remove_timestamps(table_name, options = {})
        remove_column table_name, :updated_at
        remove_column table_name, :created_at
      end

      def update_table_definition(table_name, base) #:nodoc:
        Table.new(table_name, base)
      end

      def add_index_options(table_name, column_name, options = {}) #:nodoc:
        column_names = Array(column_name)
        index_name   = index_name(table_name, column: column_names)

        options.assert_valid_keys(:unique, :order, :name, :where, :length, :internal, :using, :algorithm, :type)

        index_type = options[:unique] ? "UNIQUE" : ""
        index_type = options[:type].to_s if options.key?(:type)
        index_name = options[:name].to_s if options.key?(:name)
        max_index_length = options.fetch(:internal, false) ? index_name_length : allowed_index_name_length

        if options.key?(:algorithm)
          algorithm = index_algorithms.fetch(options[:algorithm]) {
            raise ArgumentError.new("Algorithm must be one of the following: #{index_algorithms.keys.map(&:inspect).join(', ')}")
          }
        end

        using = "USING #{options[:using]}" if options[:using].present?

        if supports_partial_index?
          index_options = options[:where] ? " WHERE #{options[:where]}" : ""
        end

        if index_name.length > max_index_length
          raise ArgumentError, "Index name '#{index_name}' on table '#{table_name}' is too long; the limit is #{max_index_length} characters"
        end
        if table_exists?(table_name) && index_name_exists?(table_name, index_name, false)
          raise ArgumentError, "Index name '#{index_name}' on table '#{table_name}' already exists"
        end
        index_columns = quoted_columns_for_index(column_names, options).join(", ")

        [index_name, index_type, index_columns, index_options, algorithm, using]
      end

      protected
        def add_index_sort_order(option_strings, column_names, options = {})
          if options.is_a?(Hash) && order = options[:order]
            case order
            when Hash
              column_names.each {|name| option_strings[name] += " #{order[name].upcase}" if order.has_key?(name)}
            when String
              column_names.each {|name| option_strings[name] += " #{order.upcase}"}
            end
          end

          return option_strings
        end

        # Overridden by the MySQL adapter for supporting index lengths
        def quoted_columns_for_index(column_names, options = {})
          option_strings = Hash[column_names.map {|name| [name, '']}]

          # add index sort order if supported
          if supports_index_sort_order?
            option_strings = add_index_sort_order(option_strings, column_names, options)
          end

          column_names.map {|name| quote_column_name(name) + option_strings[name]}
        end

        def options_include_default?(options)
          options.include?(:default) && !(options[:null] == false && options[:default].nil?)
        end

        def index_name_for_remove(table_name, options = {})
          index_name = index_name(table_name, options)

          unless index_name_exists?(table_name, index_name, true)
            if options.is_a?(Hash) && options.has_key?(:name)
              options_without_column = options.dup
              options_without_column.delete :column
              index_name_without_column = index_name(table_name, options_without_column)

              return index_name_without_column if index_name_exists?(table_name, index_name_without_column, false)
            end

            raise ArgumentError, "Index name '#{index_name}' on table '#{table_name}' does not exist"
          end

          index_name
        end

        def rename_table_indexes(table_name, new_name)
          indexes(new_name).each do |index|
            generated_index_name = index_name(table_name, column: index.columns)
            if generated_index_name == index.name
              rename_index new_name, generated_index_name, index_name(new_name, column: index.columns)
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

      private
      def create_table_definition(name, temporary, options, as = nil)
        TableDefinition.new native_database_types, name, temporary, options, as
      end

      def create_alter_table(name)
        AlterTable.new create_table_definition(name, false, {})
      end

      def foreign_key_name(table_name, options) # :nodoc:
        identifier = "#{table_name}_#{options.fetch(:column)}_fk"
        hashed_identifier = Digest::SHA256.hexdigest(identifier).first(10)
        options.fetch(:name) do
          "fk_rails_#{hashed_identifier}"
        end
      end

      def validate_index_length!(table_name, new_name)
        if new_name.length > allowed_index_name_length
          raise ArgumentError, "Index name '#{new_name}' on table '#{table_name}' is too long; the limit is #{allowed_index_name_length} characters"
        end
      end
    end
  end
end
