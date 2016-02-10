module ActiveRecord
  module ConnectionAdapters # :nodoc:
    # The goal of this module is to move Adapter specific column
    # definitions to the Adapter instead of having it in the schema
    # dumper itself. This code represents the normal case.
    # We can then redefine how certain data types may be handled in the schema dumper on the
    # Adapter level by over-writing this code inside the database specific adapters
    module ColumnDumper
      def column_spec(column)
        spec = prepare_column_options(column)
        (spec.keys - [:name, :type]).each{ |k| spec[k].insert(0, "#{k}: ")}
        spec
      end

      def column_spec_for_primary_key(column)
        return if column.type == :integer
        spec = { id: schema_type(column).inspect }
        spec.merge!(prepare_column_options(column).delete_if { |key, _| [:name, :type].include?(key) })
      end

      # This can be overridden on an Adapter level basis to support other
      # extended datatypes (Example: Adding an array option in the
      # PostgreSQL::ColumnDumper)
      def prepare_column_options(column)
        spec = {}
        spec[:name]      = column.name.inspect
        spec[:type]      = schema_type(column).to_s
        spec[:null]      = 'false' unless column.null

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
        spec[:default]   = default unless default.nil?

        if collation = schema_collation(column)
          spec[:collation] = collation
        end

        spec
      end

      # Lists the valid migration options
      def migration_keys
        [:name, :limit, :precision, :scale, :default, :null, :collation]
      end

      private

      def schema_type(column)
        column.type
      end

      def schema_limit(column)
        limit = column.limit
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
