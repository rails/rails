module ActiveRecord
  module ConnectionAdapters
    module MySQL
      class Column < ConnectionAdapters::Column # :nodoc:
        delegate :extra, to: :sql_type_metadata, allow_nil: true

        def unsigned?
          /\bunsigned\z/.match?(sql_type)
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
