module ActiveRecord
  module ConnectionAdapters
    module MySQL
      class Column < ConnectionAdapters::Column # :nodoc:
        delegate :extra, to: :sql_type_metadata, allow_nil: true

        def unsigned?
          /\bunsigned\z/ === sql_type
        end

        def case_sensitive?
          collation && collation !~ /_ci\z/
        end

        def auto_increment?
          extra == "auto_increment"
        end
      end
    end
  end
end
