require 'ipaddr'

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    # The goal of this module is to move Adapter specific column
    # definitions to the Adapter instead of having it in the schema
    # dumper itself. This code represents the normal case.
    # We can then redefine how certain data types may be handled in the schema dumper on the
    # Adapter level by over-writing this code inside the database specific adapters
    module ColumnDumper
      def column_spec(column, types)
        spec = prepare_column_options(column, types)
        (spec.keys - [:name, :type]).each{ |k| spec[k].insert(0, "#{k.to_s}: ")}
        spec
      end

      # This can be overridden on a Adapter level basis to support other
      # extended datatypes (Example: Adding an array option in the
      # PostgreSQLAdapter)
      def prepare_column_options(column, types)
        spec = {}
        spec[:name]      = column.name.inspect

        # AR has an optimization which handles zero-scale decimals as integers. This
        # code ensures that the dumper still dumps the column as a decimal.
        spec[:type]      = if column.type == :integer && /^(numeric|decimal)/ =~ column.sql_type
                             'decimal'
                           else
                             column.type.to_s
                           end
        spec[:limit]     = column.limit.inspect if column.limit != types[column.type][:limit] && spec[:type] != 'decimal'
        spec[:precision] = column.precision.inspect if column.precision
        spec[:scale]     = column.scale.inspect if column.scale
        spec[:null]      = 'false' unless column.null
        spec[:default]   = default_string(column.default) if column.has_default?
        spec
      end

      # Lists the valid migration options
      def migration_keys
        [:name, :limit, :precision, :scale, :default, :null]
      end

      private

        def default_string(value)
          case value
          when BigDecimal
            value.to_s
          when Date, DateTime, Time
            "'#{value.to_s(:db)}'"
          when Range
            # infinity dumps as Infinity, which causes uninitialized constant error
            value.inspect.gsub('Infinity', '::Float::INFINITY')
          when IPAddr
            subnet_mask = value.instance_variable_get(:@mask_addr)

            # If the subnet mask is equal to /32, don't output it
            if subnet_mask == (2**32 - 1)
              "\"#{value.to_s}\""
            else
              "\"#{value.to_s}/#{subnet_mask.to_s(2).count('1')}\""
            end
          else
            value.inspect
          end
        end
    end
  end
end
