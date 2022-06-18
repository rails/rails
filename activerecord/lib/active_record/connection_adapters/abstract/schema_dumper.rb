# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    class SchemaDumper < SchemaDumper # :nodoc:
      DEFAULT_DATETIME_PRECISION = 6 # :nodoc:

      def self.create(connection, options)
        new(connection, options)
      end

      private
        def column_spec(column)
          [schema_type_with_virtual(column), prepare_column_options(column)]
        end

        def column_spec_for_primary_key(column)
          spec = {}
          spec[:id] = schema_type(column).inspect unless default_primary_key?(column)
          spec.merge!(prepare_column_options(column).except!(:null))
          spec[:default] ||= "nil" if explicit_primary_key_default?(column)
          spec
        end

        def prepare_column_options(column)
          spec = {}
          spec[:limit] = schema_limit(column)
          spec[:precision] = schema_precision(column)
          spec[:scale] = schema_scale(column)
          spec[:default] = schema_default(column)
          spec[:null] = "false" unless column.null
          spec[:collation] = schema_collation(column)
          spec[:comment] = column.comment.inspect if column.comment.present?
          spec.compact!
          spec
        end

        def default_primary_key?(column)
          schema_type(column) == :bigint
        end

        def explicit_primary_key_default?(column)
          false
        end

        def schema_type_with_virtual(column)
          if @connection.supports_virtual_columns? && column.virtual?
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
          limit.inspect if limit && limit != @connection.native_database_types[column.type][:limit]
        end

        def schema_precision(column)
          if column.type == :datetime
            case column.precision
            when nil
              "nil"
            when DEFAULT_DATETIME_PRECISION
              nil
            else
              column.precision.inspect
            end
          elsif column.precision
            column.precision.inspect
          end
        end

        def schema_scale(column)
          column.scale.inspect if column.scale
        end

        def schema_default(column)
          return unless column.has_default?
          type = @connection.lookup_cast_type_from_column(column)
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
