module ActiveRecord
  module ConnectionAdapters
    module MySQL
      class Column < ConnectionAdapters::Column # :nodoc:
        delegate :extra, to: :sql_type_metadata, allow_nil: true

        def unsigned?
          # enum and set types do not allow being defined as unsigned.
          !/\A(?:enum|set)\b/.match?(sql_type) && /\bunsigned\b/.match?(sql_type)
        end

        def case_sensitive?
          collation && !/_ci\z/.match?(collation)
        end

        def auto_increment?
          extra == "auto_increment"
        end
      end
    end
  end
end
