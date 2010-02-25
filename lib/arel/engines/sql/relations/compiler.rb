module Arel
  module SqlCompiler
    class GenericCompiler
      attr_reader :relation

      def initialize(relation)
        @relation = relation
      end

      def select_sql
        build_query \
          "SELECT     #{select_clauses.join(', ')}",
          "FROM       #{from_clauses}",
          (joins(self)                                   unless joins(self).blank? ),
          ("WHERE     #{where_clauses.join(" AND ")}"    unless wheres.blank?      ),
          ("GROUP BY  #{group_clauses.join(', ')}"       unless groupings.blank?   ),
          ("HAVING    #{having_clauses.join(', ')}"      unless havings.blank?     ),
          ("ORDER BY  #{order_clauses.join(', ')}"       unless orders.blank?      ),
          ("LIMIT     #{taken}"                          unless taken.blank?       ),
          ("OFFSET    #{skipped}"                        unless skipped.blank?     ),
          ("#{locked}"                                   unless locked.blank?)
      end

      def limited_update_conditions(conditions, taken)
        conditions << " LIMIT #{taken}"
        quoted_primary_key = engine.quote_table_name(primary_key)
        "WHERE #{quoted_primary_key} IN (SELECT #{quoted_primary_key} FROM #{engine.connection.quote_table_name table.name} #{conditions})"
      end

      def add_limit_on_delete(taken)
        "LIMIT #{taken}"
      end

      def supports_insert_with_returning?
        false
      end

    protected
      def method_missing(method, *args, &block)
        relation.send(method, *args, &block)
      end

      def build_query(*parts)
        parts.compact.join(" ")
      end

    end

  end
end
