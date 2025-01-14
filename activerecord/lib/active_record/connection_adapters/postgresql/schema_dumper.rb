# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      class SchemaDumper < ConnectionAdapters::SchemaDumper # :nodoc:
        private
          def extensions(stream)
            extensions = @connection.extensions
            if extensions.any?
              stream.puts "  # These are extensions that must be enabled in order to support this database"
              extensions.sort.each do |extension|
                stream.puts "  enable_extension #{extension.inspect}"
              end
              stream.puts
            end
          end

          def types(stream)
            types = @connection.enum_types
            if types.any?
              stream.puts "  # Custom types defined in this database."
              stream.puts "  # Note that some types may not work with other database engines. Be careful if changing database."
              types.sort.each do |name, values|
                stream.puts "  create_enum #{name.inspect}, #{values.inspect}"
              end
              stream.puts
            end
          end

          def schemas(stream)
            schema_names = @connection.schema_names - ["public"]

            if schema_names.any?
              schema_names.sort.each do |name|
                stream.puts "  create_schema #{name.inspect}"
              end
              stream.puts
            end
          end

          def exclusion_constraints_in_create(table, stream)
            if (exclusion_constraints = @connection.exclusion_constraints(table)).any?
              add_exclusion_constraint_statements = exclusion_constraints.map do |exclusion_constraint|
                parts = [
                  "t.exclusion_constraint #{exclusion_constraint.expression.inspect}"
                ]

                parts << "where: #{exclusion_constraint.where.inspect}" if exclusion_constraint.where
                parts << "using: #{exclusion_constraint.using.inspect}" if exclusion_constraint.using
                parts << "deferrable: #{exclusion_constraint.deferrable.inspect}" if exclusion_constraint.deferrable

                if exclusion_constraint.export_name_on_schema_dump?
                  parts << "name: #{exclusion_constraint.name.inspect}"
                end

                "    #{parts.join(', ')}"
              end

              stream.puts add_exclusion_constraint_statements.sort.join("\n")
            end
          end

          def unique_constraints_in_create(table, stream)
            if (unique_constraints = @connection.unique_constraints(table)).any?
              add_unique_constraint_statements = unique_constraints.map do |unique_constraint|
                parts = [
                  "t.unique_constraint #{unique_constraint.column.inspect}"
                ]

                parts << "nulls_not_distinct: #{unique_constraint.nulls_not_distinct.inspect}" if unique_constraint.nulls_not_distinct
                parts << "deferrable: #{unique_constraint.deferrable.inspect}" if unique_constraint.deferrable

                if unique_constraint.export_name_on_schema_dump?
                  parts << "name: #{unique_constraint.name.inspect}"
                end

                "    #{parts.join(', ')}"
              end

              stream.puts add_unique_constraint_statements.sort.join("\n")
            end
          end

          def prepare_column_options(column)
            spec = super
            spec[:array] = "true" if column.array?

            if @connection.supports_virtual_columns? && column.virtual?
              spec[:as] = extract_expression_for_virtual_column(column)
              spec[:stored] = true
              spec = { type: schema_type(column).inspect }.merge!(spec)
            end

            spec[:enum_type] = column.sql_type.inspect if column.enum?

            spec
          end

          def default_primary_key?(column)
            schema_type(column) == :bigserial
          end

          def explicit_primary_key_default?(column)
            column.type == :uuid || (column.type == :integer && !column.serial?)
          end

          def schema_type(column)
            return super unless column.serial?

            if column.bigint?
              :bigserial
            else
              :serial
            end
          end

          def schema_expression(column)
            super unless column.serial?
          end

          def extract_expression_for_virtual_column(column)
            column.default_function.inspect
          end
      end
    end
  end
end
