require 'active_record/migration/join_table'

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module SchemaStatements
      include ActiveRecord::Migration::JoinTable

      # Returns a Hash of mappings from the abstract data types to the native
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
      def table_exists?(table_name)
        tables.include?(table_name.to_s)
      end

      # Returns an array of indexes for the given table.
      # def indexes(table_name, name = nil) end

      # Checks to see if an index exists on a table for a given index definition.
      #
      #  # Check an index exists
      #  index_exists?(:suppliers, :company_id)
      #
      #  # Check an index on multiple columns exists
      #  index_exists?(:suppliers, [:company_id, :company_type])
      #
      #  # Check a unique index exists
      #  index_exists?(:suppliers, :company_id, unique: true)
      #
      #  # Check an index with a custom name exists
      #  index_exists?(:suppliers, :company_id, name: "idx_company_id"
      def index_exists?(table_name, column_name, options = {})
        column_names = Array(column_name)
        index_name = options.key?(:name) ? options[:name].to_s : index_name(table_name, :column => column_names)
        if options[:unique]
          indexes(table_name).any?{ |i| i.unique && i.name == index_name }
        else
          indexes(table_name).any?{ |i| i.name == index_name }
        end
      end

      # Returns an array of Column objects for the table specified by +table_name+.
      # See the concrete implementation for details on the expected parameter values.
      def columns(table_name) end

      # Checks to see if a column exists in a given table.
      #
      #  # Check a column exists
      #  column_exists?(:suppliers, :name)
      #
      #  # Check a column exists of a particular type
      #  column_exists?(:suppliers, :name, :string)
      #
      #  # Check a column exists with a specific definition
      #  column_exists?(:suppliers, :name, :string, limit: 100)
      #  column_exists?(:suppliers, :name, :string, default: 'default')
      #  column_exists?(:suppliers, :name, :string, null: false)
      #  column_exists?(:suppliers, :tax, :decimal, precision: 8, scale: 2)
      def column_exists?(table_name, column_name, type = nil, options = {})
        columns(table_name).any?{ |c| c.name == column_name.to_s &&
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
      #  # create_table() passes a TableDefinition object to the block.
      #  # This form will not only create the table, but also columns for the
      #  # table.
      #
      #  create_table(:suppliers) do |t|
      #    t.column :name, :string, limit: 60
      #    # Other fields here
      #  end
      #
      # === Block form, with shorthand
      #  # You can also use the column types as method calls, rather than calling the column method.
      #  create_table(:suppliers) do |t|
      #    t.string :name, limit: 60
      #    # Other fields here
      #  end
      #
      # === Regular form
      #  # Creates a table called 'suppliers' with no columns.
      #  create_table(:suppliers)
      #  # Add a column to 'suppliers'.
      #  add_column(:suppliers, :name, :string, {limit: 60})
      #
      # The +options+ hash can include the following keys:
      # [<tt>:id</tt>]
      #   Whether to automatically add a primary key column. Defaults to true.
      #   Join tables for +has_and_belongs_to_many+ should set it to false.
      # [<tt>:primary_key</tt>]
      #   The name of the primary key, if one is to be added automatically.
      #   Defaults to +id+. If <tt>:id</tt> is false this option is ignored.
      #
      #   Also note that this just sets the primary key in the table. You additionally
      #   need to configure the primary key in the model via +self.primary_key=+.
      #   Models do NOT auto-detect the primary key from their table definition.
      #
      # [<tt>:options</tt>]
      #   Any extra options you want appended to the table definition.
      # [<tt>:temporary</tt>]
      #   Make a temporary table.
      # [<tt>:force</tt>]
      #   Set to true to drop the table before creating it.
      #   Defaults to false.
      #
      # ====== Add a backend specific option to the generated SQL (MySQL)
      #  create_table(:suppliers, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8')
      # generates:
      #  CREATE TABLE suppliers (
      #    id int(11) DEFAULT NULL auto_increment PRIMARY KEY
      #  ) ENGINE=InnoDB DEFAULT CHARSET=utf8
      #
      # ====== Rename the primary key column
      #  create_table(:objects, primary_key: 'guid') do |t|
      #    t.column :name, :string, limit: 80
      #  end
      # generates:
      #  CREATE TABLE objects (
      #    guid int(11) DEFAULT NULL auto_increment PRIMARY KEY,
      #    name varchar(80)
      #  )
      #
      # ====== Do not add a primary key column
      #  create_table(:categories_suppliers, id: false) do |t|
      #    t.column :category_id, :integer
      #    t.column :supplier_id, :integer
      #  end
      # generates:
      #  CREATE TABLE categories_suppliers (
      #    category_id int,
      #    supplier_id int
      #  )
      #
      # See also TableDefinition#column for details on how to create columns.
      def create_table(table_name, options = {})
        td = table_definition
        td.primary_key(options[:primary_key] || Base.get_primary_key(table_name.to_s.singularize)) unless options[:id] == false

        yield td if block_given?

        if options[:force] && table_exists?(table_name)
          drop_table(table_name, options)
        end

        create_sql = "CREATE#{' TEMPORARY' if options[:temporary]} TABLE "
        create_sql << "#{quote_table_name(table_name)} ("
        create_sql << td.to_sql
        create_sql << ") #{options[:options]}"
        execute create_sql
        td.indexes.each_pair { |c,o| add_index table_name, c, o }
      end

      # Creates a new join table with the name created using the lexical order of the first two
      # arguments. These arguments can be a String or a Symbol.
      #
      #  # Creates a table called 'assemblies_parts' with no id.
      #  create_join_table(:assemblies, :parts)
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
      # ====== Add a backend specific option to the generated SQL (MySQL)
      #  create_join_table(:assemblies, :parts, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8')
      # generates:
      #  CREATE TABLE assemblies_parts (
      #    assembly_id int NOT NULL,
      #    part_id int NOT NULL,
      #  ) ENGINE=InnoDB DEFAULT CHARSET=utf8
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

      # A block for changing columns in +table+.
      #
      #  # change_table() yields a Table instance
      #  change_table(:suppliers) do |t|
      #    t.column :name, :string, limit: 60
      #    # Other column alterations here
      #  end
      #
      # The +options+ hash can include the following keys:
      # [<tt>:bulk</tt>]
      #   Set this to true to make this a bulk alter query, such as
      #   ALTER TABLE `users` ADD COLUMN age INT(11), ADD COLUMN birthdate DATETIME ...
      #
      #   Defaults to false.
      #
      # ====== Add a column
      #  change_table(:suppliers) do |t|
      #    t.column :name, :string, limit: 60
      #  end
      #
      # ====== Add 2 integer columns
      #  change_table(:suppliers) do |t|
      #    t.integer :width, :height, null: false, default: 0
      #  end
      #
      # ====== Add created_at/updated_at columns
      #  change_table(:suppliers) do |t|
      #    t.timestamps
      #  end
      #
      # ====== Add a foreign key column
      #  change_table(:suppliers) do |t|
      #    t.references :company
      #  end
      #
      # Creates a <tt>company_id(integer)</tt> column
      #
      # ====== Add a polymorphic foreign key column
      #  change_table(:suppliers) do |t|
      #    t.belongs_to :company, polymorphic: true
      #  end
      #
      # Creates <tt>company_type(varchar)</tt> and <tt>company_id(integer)</tt> columns
      #
      # ====== Remove a column
      #  change_table(:suppliers) do |t|
      #    t.remove :company
      #  end
      #
      # ====== Remove several columns
      #  change_table(:suppliers) do |t|
      #    t.remove :company_id
      #    t.remove :width, :height
      #  end
      #
      # ====== Remove an index
      #  change_table(:suppliers) do |t|
      #    t.remove_index :company_id
      #  end
      #
      # See also Table for details on
      # all of the various column transformation
      def change_table(table_name, options = {})
        if supports_bulk_alter? && options[:bulk]
          recorder = ActiveRecord::Migration::CommandRecorder.new(self)
          yield Table.new(table_name, recorder)
          bulk_change_table(table_name, recorder.commands)
        else
          yield Table.new(table_name, self)
        end
      end

      # Renames a table.
      #
      #  rename_table('octopuses', 'octopi')
      def rename_table(table_name, new_name)
        raise NotImplementedError, "rename_table is not implemented"
      end

      # Drops a table from the database.
      def drop_table(table_name, options = {})
        execute "DROP TABLE #{quote_table_name(table_name)}"
      end

      # Adds a new column to the named table.
      # See TableDefinition#column for details of the options you can use.
      def add_column(table_name, column_name, type, options = {})
        add_column_sql = "ALTER TABLE #{quote_table_name(table_name)} ADD #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
        add_column_options!(add_column_sql, options)
        execute(add_column_sql)
      end

      # Removes the column(s) from the table definition.
      #
      #  remove_column(:suppliers, :qualification)
      #  remove_columns(:suppliers, :qualification, :experience)
      def remove_column(table_name, *column_names)
        columns_for_remove(table_name, *column_names).each {|column_name| execute "ALTER TABLE #{quote_table_name(table_name)} DROP #{column_name}" }
      end
      alias :remove_columns :remove_column

      # Changes the column's definition according to the new options.
      # See TableDefinition#column for details of the options you can use.
      #
      #  change_column(:suppliers, :name, :string, limit: 80)
      #  change_column(:accounts, :description, :text)
      def change_column(table_name, column_name, type, options = {})
        raise NotImplementedError, "change_column is not implemented"
      end

      # Sets a new default value for a column.
      #
      #  change_column_default(:suppliers, :qualification, 'new')
      #  change_column_default(:accounts, :authorized, 1)
      #  change_column_default(:users, :email, nil)
      def change_column_default(table_name, column_name, default)
        raise NotImplementedError, "change_column_default is not implemented"
      end

      # Renames a column.
      #
      #  rename_column(:suppliers, :description, :name)
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
      #  add_index(:suppliers, :name)
      # generates
      #  CREATE INDEX suppliers_name_index ON suppliers(name)
      #
      # ====== Creating a unique index
      #  add_index(:accounts, [:branch_id, :party_id], unique: true)
      # generates
      #  CREATE UNIQUE INDEX accounts_branch_id_party_id_index ON accounts(branch_id, party_id)
      #
      # ====== Creating a named index
      #  add_index(:accounts, [:branch_id, :party_id], unique: true, name: 'by_branch_party')
      # generates
      #  CREATE UNIQUE INDEX by_branch_party ON accounts(branch_id, party_id)
      #
      # ====== Creating an index with specific key length
      #  add_index(:accounts, :name, name: 'by_name', length: 10)
      # generates
      #  CREATE INDEX by_name ON accounts(name(10))
      #
      #  add_index(:accounts, [:name, :surname], name: 'by_name_surname', length: {name: 10, surname: 15})
      # generates
      #  CREATE INDEX by_name_surname ON accounts(name(10), surname(15))
      #
      # Note: SQLite doesn't support index length
      #
      # ====== Creating an index with a sort order (desc or asc, asc is the default)
      #  add_index(:accounts, [:branch_id, :party_id, :surname], order: {branch_id: :desc, party_id: :asc})
      # generates
      #  CREATE INDEX by_branch_desc_party ON accounts(branch_id DESC, party_id ASC, surname)
      #
      # Note: mysql doesn't yet support index order (it accepts the syntax but ignores it)
      #
      # ====== Creating a partial index
      #  add_index(:accounts, [:branch_id, :party_id], unique: true, where: "active")
      # generates
      #  CREATE UNIQUE INDEX index_accounts_on_branch_id_and_party_id ON accounts(branch_id, party_id) WHERE active
      #
      # Note: only supported by PostgreSQL
      #
      def add_index(table_name, column_name, options = {})
        index_name, index_type, index_columns, index_options = add_index_options(table_name, column_name, options)
        execute "CREATE #{index_type} INDEX #{quote_column_name(index_name)} ON #{quote_table_name(table_name)} (#{index_columns})#{index_options}"
      end

      # Remove the given index from the table.
      #
      # Remove the index_accounts_on_column in the accounts table.
      #   remove_index :accounts, :column
      # Remove the index named index_accounts_on_branch_id in the accounts table.
      #   remove_index :accounts, column: :branch_id
      # Remove the index named index_accounts_on_branch_id_and_party_id in the accounts table.
      #   remove_index :accounts, column: [:branch_id, :party_id]
      # Remove the index named by_branch_party in the accounts table.
      #   remove_index :accounts, name: :by_branch_party
      def remove_index(table_name, options = {})
        remove_index!(table_name, index_name_for_remove(table_name, options))
      end

      def remove_index!(table_name, index_name) #:nodoc:
        execute "DROP INDEX #{quote_column_name(index_name)} ON #{quote_table_name(table_name)}"
      end

      # Rename an index.
      #
      # Rename the index_people_on_last_name index to index_users_on_last_name
      #   rename_index :people, 'index_people_on_last_name', 'index_users_on_last_name'
      def rename_index(table_name, old_name, new_name)
        # this is a naive implementation; some DBs may support this more efficiently (Postgres, for instance)
        old_index_def = indexes(table_name).detect { |i| i.name == old_name }
        return unless old_index_def
        remove_index(table_name, :name => old_name)
        add_index(table_name, old_index_def.columns, :name => new_name, :unique => old_index_def.unique)
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

      # Verify the existence of an index with a given name.
      #
      # The default argument is returned if the underlying implementation does not define the indexes method,
      # as there's no way to determine the correct answer in that case.
      def index_name_exists?(table_name, index_name, default)
        return default unless respond_to?(:indexes)
        index_name = index_name.to_s
        indexes(table_name).detect { |i| i.name == index_name }
      end

      # Adds a reference. Optionally adds a +type+ column, if <tt>:polymorphic</tt> option is provided.
      # <tt>add_reference</tt> and <tt>add_belongs_to</tt> are acceptable.
      #
      # ====== Create a user_id column
      #  add_reference(:products, :user)
      #
      # ====== Create a supplier_id and supplier_type columns
      #  add_belongs_to(:products, :supplier, polymorphic: true)
      #
      # ====== Create a supplier_id, supplier_type columns and appropriate index
      #  add_reference(:products, :supplier, polymorphic: true, index: true)
      #
      def add_reference(table_name, ref_name, options = {})
        polymorphic = options.delete(:polymorphic)
        index_options = options.delete(:index)
        add_column(table_name, "#{ref_name}_id", :integer, options)
        add_column(table_name, "#{ref_name}_type", :string, polymorphic.is_a?(Hash) ? polymorphic : options) if polymorphic
        add_index(table_name, polymorphic ? %w[id type].map{ |t| "#{ref_name}_#{t}" } : "#{ref_name}_id", index_options.is_a?(Hash) ? index_options : nil) if index_options
      end
      alias :add_belongs_to :add_reference

      # Removes the reference(s). Also removes a +type+ column if one exists.
      # <tt>remove_reference</tt>, <tt>remove_references</tt> and <tt>remove_belongs_to</tt> are acceptable.
      #
      # ====== Remove the reference
      #  remove_reference(:products, :user, index: true)
      #
      # ====== Remove polymorphic reference
      #  remove_reference(:products, :supplier, polymorphic: true)
      #
      def remove_reference(table_name, ref_name, options = {})
        remove_column(table_name, "#{ref_name}_id")
        remove_column(table_name, "#{ref_name}_type") if options[:polymorphic]
      end
      alias :remove_belongs_to :remove_reference

      # Returns a string of <tt>CREATE TABLE</tt> SQL statement(s) for recreating the
      # entire structure of the database.
      def structure_dump
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
          type
        end
      end

      def add_column_options!(sql, options) #:nodoc:
        sql << " DEFAULT #{quote(options[:default], options[:column])}" if options_include_default?(options)
        # must explicitly check for :null to allow change_column to work on migrations
        if options[:null] == false
          sql << " NOT NULL"
        end
      end

      # SELECT DISTINCT clause for a given set of columns and a given ORDER BY clause.
      # Both PostgreSQL and Oracle overrides this for custom DISTINCT syntax.
      #
      #   distinct("posts.id", "posts.created_at desc")
      def distinct(columns, order_by)
        "DISTINCT #{columns}"
      end

      # Adds timestamps (created_at and updated_at) columns to the named table.
      #
      #  add_timestamps(:suppliers)
      def add_timestamps(table_name)
        add_column table_name, :created_at, :datetime
        add_column table_name, :updated_at, :datetime
      end

      # Removes the timestamp columns (created_at and updated_at) from the table definition.
      #
      #  remove_timestamps(:suppliers)
      def remove_timestamps(table_name)
        remove_column table_name, :updated_at
        remove_column table_name, :created_at
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

        # Overridden by the mysql adapter for supporting index lengths
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

        def add_index_options(table_name, column_name, options = {})
          column_names = Array(column_name)
          index_name   = index_name(table_name, column: column_names)

          if Hash === options # legacy support, since this param was a string
            options.assert_valid_keys(:unique, :order, :name, :where, :length)

            index_type = options[:unique] ? "UNIQUE" : ""
            index_name = options[:name].to_s if options.key?(:name)

            if supports_partial_index?
              index_options = options[:where] ? " WHERE #{options[:where]}" : ""
            end
          else
            if options
              message = "Passing a string as third argument of `add_index` is deprecated and will" +
                " be removed in Rails 4.1." +
                " Use add_index(#{table_name.inspect}, #{column_name.inspect}, unique: true) instead"

              ActiveSupport::Deprecation.warn message
            end

            index_type = options
          end

          if index_name.length > index_name_length
            raise ArgumentError, "Index name '#{index_name}' on table '#{table_name}' is too long; the limit is #{index_name_length} characters"
          end
          if index_name_exists?(table_name, index_name, false)
            raise ArgumentError, "Index name '#{index_name}' on table '#{table_name}' already exists"
          end
          index_columns = quoted_columns_for_index(column_names, options).join(", ")

          [index_name, index_type, index_columns, index_options]
        end

        def index_name_for_remove(table_name, options = {})
          index_name = index_name(table_name, options)

          unless index_name_exists?(table_name, index_name, true)
            raise ArgumentError, "Index name '#{index_name}' on table '#{table_name}' does not exist"
          end

          index_name
        end

        def columns_for_remove(table_name, *column_names)
          raise ArgumentError.new("You must specify at least one column name. Example: remove_column(:people, :first_name)") if column_names.blank?
          column_names.map {|column_name| quote_column_name(column_name) }
        end

      private
      def table_definition
        TableDefinition.new(self)
      end
    end
  end
end
