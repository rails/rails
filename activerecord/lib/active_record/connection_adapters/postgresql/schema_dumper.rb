module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module ColumnDumper
        def column_spec_for_primary_key(column)
          spec = {}
          if column.serial?
            return unless column.bigint?
            spec[:id] = ':bigserial'
          elsif column.type == :uuid
            spec[:id] = ':uuid'
            spec[:default] = schema_default(column) || 'nil'
          else
            spec[:id] = schema_type(column).inspect
            spec.merge!(prepare_column_options(column).delete_if { |key, _| [:name, :type, :null].include?(key) })
          end
          spec
        end

        # Adds +:array+ option to the default set
        def prepare_column_options(column)
          spec = super
          spec[:array] = 'true' if column.array?
          spec
        end

        # Adds +:array+ as a valid migration key
        def migration_keys
          super + [:array]
        end

        private

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
