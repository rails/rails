module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module ColumnDumper # :nodoc:
        # Adds +:array+ option to the default set
        def prepare_column_options(column)
          spec = super
          spec[:array] = "true" if column.array?
          spec
        end

        # Adds +:array+ as a valid migration key
        def migration_keys
          super + [:array]
        end

        private

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
