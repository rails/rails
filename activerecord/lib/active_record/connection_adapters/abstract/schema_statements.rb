module ActiveRecord
  module ConnectionAdapters # :nodoc:
    # TODO: Document me!
    module SchemaStatements
      def native_database_types #:nodoc:
        {}
      end

      # def tables(name = nil) end

      # Returns an array of indexes for the given table.
      # def indexes(table_name, name = nil) end

      # Returns an array of column objects for the table specified by +table_name+.
      def columns(table_name, name = nil) end


      def create_table(name, options = {})
        table_definition = TableDefinition.new(self)
        table_definition.primary_key(options[:primary_key] || "id") unless options[:id] == false

        yield table_definition
        create_sql = "CREATE#{' TEMPORARY' if options[:temporary]} TABLE "
        create_sql << "#{name} ("
        create_sql << table_definition.to_sql
        create_sql << ") #{options[:options]}"
        execute create_sql
      end

      def drop_table(name)
        execute "DROP TABLE #{name}"
      end

      def add_column(table_name, column_name, type, options = {})
        add_column_sql = "ALTER TABLE #{table_name} ADD #{column_name} #{type_to_sql(type, options[:limit])}"
        add_column_options!(add_column_sql, options)
        execute(add_column_sql)
      end

      def remove_column(table_name, column_name)
        execute "ALTER TABLE #{table_name} DROP #{column_name}"
      end      

      def change_column(table_name, column_name, type, options = {})
        raise NotImplementedError, "change_column is not implemented"
      end

      def change_column_default(table_name, column_name, default)
        raise NotImplementedError, "change_column_default is not implemented"
      end

      def rename_column(table_name, column_name, new_column_name)
        raise NotImplementedError, "rename_column is not implemented"
      end

      # Create a new index on the given table. By default, it will be named
      # <code>"#{table_name}_#{column_name.to_a.first}_index"</code>, but you
      # can explicitly name the index by passing <code>:name => "..."</code>
      # as the last parameter. Unique indexes may be created by passing
      # <code>:unique => true</code>.
      def add_index(table_name, column_name, options = {})
        index_name = "#{table_name}_#{column_name.to_a.first}_index"

        if Hash === options # legacy support, since this param was a string
          index_type = options[:unique] ? "UNIQUE" : ""
          index_name = options[:name] || index_name
        else
          index_type = options
        end

        execute "CREATE #{index_type} INDEX #{index_name} ON #{table_name} (#{column_name.to_a.join(", ")})"
      end

      # Remove the given index from the table.
      #
      #   remove_index :my_table, :column => :foo
      #   remove_index :my_table, :name => :my_index_on_foo
      #
      # The first version will remove the index named
      # <code>"#{my_table}_#{column}_index"</code> from the table. The
      # second removes the named column from the table.
      def remove_index(table_name, options = {})
        if Hash === options # legacy support
          if options[:column]
            index_name = "#{table_name}_#{options[:column]}_index"
          elsif options[:name]
            index_name = options[:name]
          else
            raise ArgumentError, "You must specify the index name"
          end
        else
          index_name = "#{table_name}_#{options}_index"
        end

        execute "DROP INDEX #{index_name} ON #{table_name}"
      end


      # Returns a string of the CREATE TABLE SQL statements for recreating the entire structure of the database.
      def structure_dump #:nodoc:
      end

      def initialize_schema_information #:nodoc:
        begin
          execute "CREATE TABLE schema_info (version #{type_to_sql(:integer)})"
          execute "INSERT INTO schema_info (version) VALUES(0)"
        rescue ActiveRecord::StatementInvalid
          # Schema has been intialized
        end
      end

      def dump_schema_information #:nodoc:
        begin
          if (current_schema = ActiveRecord::Migrator.current_version) > 0
            return "INSERT INTO schema_info (version) VALUES (#{current_schema});" 
          end
        rescue ActiveRecord::StatementInvalid 
          # No Schema Info
        end
      end


      def type_to_sql(type, limit = nil) #:nodoc:
        native = native_database_types[type]
        limit ||= native[:limit]
        column_type_sql = native[:name]
        column_type_sql << "(#{limit})" if limit
        column_type_sql
      end            
    
      def add_column_options!(sql, options) #:nodoc:
        sql << " NOT NULL" if options[:null] == false
        sql << " DEFAULT #{quote(options[:default], options[:column])}" unless options[:default].nil?
      end
    end
  end
end