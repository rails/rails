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

            enums(stream)
          end

          def enums(stream)
            enum_types = @connection.enum_types
            return if enum_types.blank?

            stream.puts "  # These are custom enum types that must be created" \
                        " before they can be used in the schema definition"
            enum_types.each do |enum_type|
              stream.puts "  create_enum \"#{enum_type.first}\", \"#{enum_type.second.join('", "')}\""
            end
            stream.puts
          end

          def prepare_column_options(column)
            spec = super
            spec[:array] = "true" if column.array?
            spec[:enum_type] = "\"#{column.sql_type}\"" if column.type == :enum
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
      end
    end
  end
end
