# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MySQL
      class Column < ConnectionAdapters::Column # :nodoc:
        delegate :extra, to: :sql_type_metadata, allow_nil: true

        def unsigned?
          /\bunsigned(?: zerofill)?\z/.match?(sql_type)
        end

        def case_sensitive?
          collation && !collation.end_with?('_ci')
        end

        def auto_increment?
          extra == 'auto_increment'
        end

        def virtual?
          /\b(?:VIRTUAL|STORED|PERSISTENT)\b/.match?(extra)
        end
      end
    end
  end
end
