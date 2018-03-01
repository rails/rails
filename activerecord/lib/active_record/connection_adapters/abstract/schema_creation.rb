# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class AbstractAdapter
      class SchemaCreation # :nodoc:
        def initialize(conn)
          @conn = conn
          @cache = {}
        end

        def accept(o)
          m = @cache[o.class] ||= "visit_#{o.class.name.split('::').last}"
          send m, o
        end

        delegate :quote_column_name, :quote_table_name, :quote_default_expression, :type_to_sql,
          :options_include_default?, :supports_indexes_in_create?, :supports_foreign_keys_in_create?, :foreign_key_options,
          to: :@conn, private: true

        private

          def visit_AlterTable(o)
            sql = "ALTER TABLE #{quote_table_name(o.name)} ".dup
            sql << o.adds.map { |col| accept col }.join(" ")
            sql << o.foreign_key_adds.map { |fk| visit_AddForeignKey fk }.join(" ")
            sql << o.foreign_key_drops.map { |fk| visit_DropForeignKey fk }.join(" ")
          end

          def visit_ColumnDefinition(o)
            o.sql_type = type_to_sql(o.type, o.options)
            column_sql = "#{quote_column_name(o.name)} #{o.sql_type}".dup
            add_column_options!(column_sql, column_options(o)) unless o.type == :primary_key
            column_sql
          end

          def visit_AddColumnDefinition(o)
            "ADD #{accept(o.column)}".dup
          end

          def visit_TableDefinition(o)
            create_sql = "CREATE#{' TEMPORARY' if o.temporary} TABLE #{quote_table_name(o.name)} ".dup

            statements = o.columns.map { |c| accept c }
            statements << accept(o.primary_keys) if o.primary_keys

            if supports_indexes_in_create?
              statements.concat(o.indexes.map { |column_name, options| index_in_create(o.name, column_name, options) })
            end

            if supports_foreign_keys_in_create?
              statements.concat(o.foreign_keys.map { |to_table, options| foreign_key_in_create(o.name, to_table, options) })
            end

            create_sql << "(#{statements.join(', ')})" if statements.present?
            add_table_options!(create_sql, table_options(o))
            create_sql << " AS #{to_sql(o.as)}" if o.as
            create_sql
          end

          def visit_PrimaryKeyDefinition(o)
            "PRIMARY KEY (#{o.name.map { |name| quote_column_name(name) }.join(', ')})"
          end

          def visit_ForeignKeyDefinition(o)
            sql = +<<~SQL
              CONSTRAINT #{quote_column_name(o.name)}
              FOREIGN KEY (#{quote_column_name(o.column)})
                REFERENCES #{quote_table_name(o.to_table)} (#{quote_column_name(o.primary_key)})
            SQL
            sql << " #{action_sql('DELETE', o.on_delete)}" if o.on_delete
            sql << " #{action_sql('UPDATE', o.on_update)}" if o.on_update
            sql
          end

          def visit_AddForeignKey(o)
            "ADD #{accept(o)}"
          end

          def visit_DropForeignKey(name)
            "DROP CONSTRAINT #{quote_column_name(name)}"
          end

          def table_options(o)
            table_options = {}
            table_options[:comment] = o.comment
            table_options[:options] = o.options
            table_options
          end

          def add_table_options!(create_sql, options)
            if options_sql = options[:options]
              create_sql << " #{options_sql}"
            end
            create_sql
          end

          def column_options(o)
            o.options.merge(column: o)
          end

          def add_column_options!(sql, options)
            sql << " DEFAULT #{quote_default_expression(options[:default], options[:column])}" if options_include_default?(options)
            # must explicitly check for :null to allow change_column to work on migrations
            if options[:null] == false
              sql << " NOT NULL"
            end
            if options[:auto_increment] == true
              sql << " AUTO_INCREMENT"
            end
            if options[:primary_key] == true
              sql << " PRIMARY KEY"
            end
            sql
          end

          def to_sql(sql)
            sql = sql.to_sql if sql.respond_to?(:to_sql)
            sql
          end

          def foreign_key_in_create(from_table, to_table, options)
            options = foreign_key_options(from_table, to_table, options)
            accept ForeignKeyDefinition.new(from_table, to_table, options)
          end

          def action_sql(action, dependency)
            case dependency
            when :nullify then "ON #{action} SET NULL"
            when :cascade  then "ON #{action} CASCADE"
            when :restrict then "ON #{action} RESTRICT"
            else
              raise ArgumentError, <<~MSG
                '#{dependency}' is not supported for :on_update or :on_delete.
                Supported values are: :nullify, :cascade, :restrict
              MSG
            end
          end
      end
    end
    SchemaCreation = AbstractAdapter::SchemaCreation # :nodoc:
  end
end
