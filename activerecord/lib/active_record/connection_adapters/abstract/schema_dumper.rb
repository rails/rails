module ActiveRecord
  module ConnectionAdapters # :nodoc:
    # The goal of this module is to move Adapter specific column
    # definitions to the Adapter instead of having it in the schema
    # dumper itself. This code represents the normal case.
    # We can then redefine how certain data types may be handled in the schema dumper on the
    # Adapter level by over-writing this code inside the database specific adapters
    module ColumnDumper
      def column_spec(column)
        [schema_type_with_virtual(column), prepare_column_options(column)]
      end

      def column_spec_for_primary_key(column)
        return {} if default_primary_key?(column)
        spec = { id: schema_type(column).inspect }
        spec.merge!(prepare_column_options(column).except!(:null))
        spec[:default] ||= "nil" if explicit_primary_key_default?(column)
        spec
      end

      # This can be overridden on an Adapter level basis to support other
      # extended datatypes (Example: Adding an array option in the
      # PostgreSQL::ColumnDumper)
      def prepare_column_options(column)
        spec = {}

        if limit = schema_limit(column)
          spec[:limit] = limit
        end

        if precision = schema_precision(column)
          spec[:precision] = precision
        end

        if scale = schema_scale(column)
          spec[:scale] = scale
        end

        default = schema_default(column) if column.has_default?
        spec[:default] = default unless default.nil?

        spec[:null] = "false" unless column.null

        if collation = schema_collation(column)
          spec[:collation] = collation
        end

        spec[:comment] = column.comment.inspect if column.comment.present?

        spec
      end

      # Lists the valid migration options
      def migration_keys # :nodoc:
        column_options_keys
      end
      deprecate :migration_keys

      private

        def default_primary_key?(column)
          schema_type(column) == :bigint
        end

        def explicit_primary_key_default?(column)
          false
        end

        def schema_type_with_virtual(column)
          if supports_virtual_columns? && column.virtual?
            :virtual
          else
            schema_type(column)
          end
        end

        def schema_type(column)
          if column.bigint?
            :bigint
          else
            column.type
          end
        end

        def schema_limit(column)
          limit = column.limit unless column.bigint?
          limit.inspect if limit && limit != native_database_types[column.type][:limit]
        end

        def schema_precision(column)
          column.precision.inspect if column.precision
        end

        def schema_scale(column)
          column.scale.inspect if column.scale
        end

        def schema_default(column)
          type = lookup_cast_type_from_column(column)
          default = type.deserialize(column.default)
          if default.nil?
            schema_expression(column)
          else
            type.type_cast_for_schema(default)
          end
        end

        def schema_expression(column)
          "-> { #{column.default_function.inspect} }" if column.default_function
        end

        def schema_collation(column)
          column.collation.inspect if column.collation
        end
    end
  end
end
