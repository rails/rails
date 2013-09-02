require 'ipaddr'

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
        (spec.keys - [:name, :type]).each{ |k| spec[k].insert(0, "#{k.to_s}: ")}
        spec
      end

      # This can be overridden on a Adapter level basis to support other
      # extended datatypes (Example: Adding an array option in the
      # PostgreSQLAdapter)
      def prepare_column_options(column)
        spec = {}
        spec[:name]      = column.name.inspect
        # AR has an optimization which handles zero-scale decimals as integers. This
        # code ensures that the dumper still dumps the column as a decimal.
        spec[:type]      = if column.type == :integer && /^(numeric|decimal)/ =~ column.sql_type
                             'decimal'
                           elsif column.type == nil
                             column.sql_type.to_s
                           else
                             column.type.to_s
                           end
        spec[:limit]     = column.limit.inspect if column.limit != (native_database_types[column.type]|| {})[:limit]  && spec[:type] != 'decimal'
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

      def dump_columns(tbl, columns, pk)
        # dump all non-primary key columns
        column_specs = columns.map do |column|
          raise StandardError, "Unknown type '#{column.sql_type}' for column '#{column.name}'" unless valid_type?(column.type)
          next if column.name == pk
          column_spec(column)
        end.compact
        # figure out the lengths for each column based on above keys
        format_string, lengths = format_string(column_specs)
        column_specs.each do |colspec|
          values = migration_keys.zip(lengths).map { |key, len| colspec.key?(key) ? "#{colspec[key]}, " : " " * len }
          values.unshift colspec[:type]
          tbl.print((format_string % values).gsub(/,\s*$/, ''))
          tbl.puts
        end
        tbl.puts "  end"
        tbl.puts
      end

      private

        def format_string(column_specs )
          lengths = migration_keys.map { |key|
            column_specs.map { |spec|
              spec[key] ? spec[key].length + 2 : 0
            }.max
          }
          # the string we're going to sprintf our values against, with standardized column widths
          format_string = lengths.map { |len| "%-#{len}s" }
          # find the max length for the 'type' column, which is special
          type_length = column_specs.map { |column| column[:type].length }.max
          # add column type definition to our format string
          format_string.unshift "    t.%-#{type_length}s "
          format_string *= ''
          [format_string, lengths]
        end

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
