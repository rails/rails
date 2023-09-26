# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
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
        :options_include_default?, :supports_indexes_in_create?, :use_foreign_keys?,
        :quoted_columns_for_index, :supports_partial_index?, :supports_check_constraints?,
        :supports_index_include?, :supports_exclusion_constraints?, :supports_unique_constraints?,
        :supports_nulls_not_distinct?,
        to: :@conn, private: true

      private
        def visit_AlterTable(o)
          sql = +"ALTER TABLE #{quote_table_name(o.name)} "
          sql << o.adds.map { |col| accept col }.join(" ")
          sql << o.foreign_key_adds.map { |fk| visit_AddForeignKey fk }.join(" ")
          sql << o.foreign_key_drops.map { |fk| visit_DropForeignKey fk }.join(" ")
          sql << o.check_constraint_adds.map { |con| visit_AddCheckConstraint con }.join(" ")
          sql << o.check_constraint_drops.map { |con| visit_DropCheckConstraint con }.join(" ")
        end

        def visit_ColumnDefinition(o)
          o.sql_type = type_to_sql(o.type, **o.options)
          column_sql = +"#{quote_column_name(o.name)} #{o.sql_type}"
          add_column_options!(column_sql, column_options(o)) unless o.type == :primary_key
          column_sql
        end

        def visit_AddColumnDefinition(o)
          +"ADD #{accept(o.column)}"
        end

        def visit_TableDefinition(o)
          create_sql = +"CREATE#{table_modifier_in_create(o)} TABLE "
          create_sql << "IF NOT EXISTS " if o.if_not_exists
          create_sql << "#{quote_table_name(o.name)} "

          statements = o.columns.map { |c| accept c }
          statements << accept(o.primary_keys) if o.primary_keys

          if supports_indexes_in_create?
            statements.concat(o.indexes.map { |column_name, options| index_in_create(o.name, column_name, options) })
          end

          if use_foreign_keys?
            statements.concat(o.foreign_keys.map { |fk| accept fk })
          end

          if supports_check_constraints?
            statements.concat(o.check_constraints.map { |chk| accept chk })
          end

          if supports_exclusion_constraints?
            statements.concat(o.exclusion_constraints.map { |exc| accept exc })
          end

          if supports_unique_constraints?
            statements.concat(o.unique_constraints.map { |exc| accept exc })
          end

          create_sql << "(#{statements.join(', ')})" if statements.present?
          add_table_options!(create_sql, o)
          create_sql << " AS #{to_sql(o.as)}" if o.as
          create_sql
        end

        def visit_PrimaryKeyDefinition(o)
          "PRIMARY KEY (#{o.name.map { |name| quote_column_name(name) }.join(', ')})"
        end

        def visit_ForeignKeyDefinition(o)
          quoted_columns = Array(o.column).map { |c| quote_column_name(c) }
          quoted_primary_keys = Array(o.primary_key).map { |c| quote_column_name(c) }
          sql = +<<~SQL
            CONSTRAINT #{quote_column_name(o.name)}
            FOREIGN KEY (#{quoted_columns.join(", ")})
              REFERENCES #{quote_table_name(o.to_table)} (#{quoted_primary_keys.join(", ")})
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

        def visit_CreateIndexDefinition(o)
          index = o.index

          sql = ["CREATE"]
          sql << "UNIQUE" if index.unique
          sql << "INDEX"
          sql << o.algorithm if o.algorithm
          sql << "IF NOT EXISTS" if o.if_not_exists
          sql << index.type if index.type
          sql << "#{quote_column_name(index.name)} ON #{quote_table_name(index.table)}"
          sql << "USING #{index.using}" if supports_index_using? && index.using
          sql << "(#{quoted_columns(index)})"
          sql << "INCLUDE (#{quoted_include_columns(index.include)})" if supports_index_include? && index.include
          sql << "NULLS NOT DISTINCT" if supports_nulls_not_distinct? && index.nulls_not_distinct
          sql << "WHERE #{index.where}" if supports_partial_index? && index.where

          sql.join(" ")
        end

        def visit_CheckConstraintDefinition(o)
          "CONSTRAINT #{o.name} CHECK (#{o.expression})"
        end

        def visit_AddCheckConstraint(o)
          "ADD #{accept(o)}"
        end

        def visit_DropCheckConstraint(name)
          "DROP CONSTRAINT #{quote_column_name(name)}"
        end

        def quoted_columns(o)
          String === o.columns ? o.columns : quoted_columns_for_index(o.columns, o.column_options)
        end

        def supports_index_using?
          true
        end

        def add_table_options!(create_sql, o)
          create_sql << " #{o.options}" if o.options
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

        # Returns any SQL string to go between CREATE and TABLE. May be nil.
        def table_modifier_in_create(o)
          " TEMPORARY" if o.temporary
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
end
