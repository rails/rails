# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      module Maintenance # :nodoc:
        def perform_maintenance(event)
          case event
          when :analyze
            sqlite_optimize_all_tables_with_no_analysis_limit
          end
        end

        private
          def sqlite_optimize_all_tables_with_no_analysis_limit
            execute("PRAGMA optimize = 0x10002", "SQLite3::Maintenance")
          end
      end
    end
  end
end
