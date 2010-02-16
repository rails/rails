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

    protected
      def method_missing(method, *args, &block)
        relation.send(method, *args, &block)
      end

      def build_query(*parts)
        parts.compact.join(" ")
      end

      def from_clauses
        sources.blank? ? table_sql(Sql::TableReference.new(relation)) : sources
      end

      def select_clauses
        attributes.collect { |a| a.to_sql(Sql::SelectClause.new(relation)) }
      end

      def where_clauses
        wheres.collect { |w| w.to_sql(Sql::WhereClause.new(relation)) }
      end

      def group_clauses
        groupings.collect { |g| g.to_sql(Sql::GroupClause.new(relation)) }
      end

      def having_clauses
        havings.collect { |g| g.to_sql(Sql::HavingClause.new(relation)) }
      end

      def order_clauses
        orders.collect { |o| o.to_sql(Sql::OrderClause.new(relation)) }
      end
    end

  end
end
