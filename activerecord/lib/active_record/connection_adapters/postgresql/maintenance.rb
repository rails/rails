# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module Maintenance # :nodoc:
        def perform_maintenance(event)
          case event
          when :analyze
            postgres_analyze
          end
        end

        private
          def postgres_analyze
            execute("ANALYZE", "PostgreSQL::Maintenance")
          end
      end
    end
  end
end
