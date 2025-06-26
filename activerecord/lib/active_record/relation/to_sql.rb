# frozen_string_literal: true

module ActiveRecord
  module ToSQL # :nodoc:
    def exec_to_sql
      relation = if eager_loading?
        apply_join_dependency do |relation, join_dependency|
          join_dependency.apply_column_aliases(relation)
        end
      else
        self
      end

      with_connection do |conn|
        conn.unprepared_statement do
          conn.to_sql(relation.arel)
        end
      end
    end
  end
end
