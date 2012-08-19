module ActiveRecord
  module ConnectionAdapters
    module ColumnDumper
      def column_spec(column, types)
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
        (spec.keys - [:name, :type]).each{ |k| spec[k].insert(0, "#{k.inspect} => ")}
        spec
      end

      def migration_keys
        [:name, :limit, :precision, :scale, :default, :null]
      end

      def default_string(value)
        case value
        when BigDecimal
          value.to_s
        when Date, DateTime, Time
          "'#{value.to_s(:db)}'"
        else
          value.inspect
        end
      end

    end
  end
end
