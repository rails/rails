# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      class SchemaDumper < ConnectionAdapters::SchemaDumper # :nodoc:
        private
          def extensions(stream)
            extensions = @connection.extensions
            if extensions.any?
              stream.puts '  # These are extensions that must be enabled in order to support this database'
              extensions.sort.each do |extension|
                stream.puts "  enable_extension #{extension.inspect}"
              end
              stream.puts
            end
          end

          def prepare_column_options(column)
            spec = super
            spec[:array] = 'true' if column.array?
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
