module Arel
  class Relation
    def to_sql(formatter = Sql::SelectStatement.new(self))
      formatter.select select_sql, self
    end

    def select_sql
      [
        "SELECT     #{select_clauses.join(', ')}",
        "FROM       #{table_sql(Sql::TableReference.new(self))}",
        (joins(self)                                   unless joins(self).blank? ),
        ("WHERE     #{where_clauses.join("\n\tAND ")}" unless wheres.blank?      ),
        ("GROUP BY  #{group_clauses.join(', ')}"       unless groupings.blank?   ),
        ("ORDER BY  #{order_clauses.join(', ')}"       unless orders.blank?      ),
        ("LIMIT     #{taken}"                          unless taken.blank?       ),
        ("OFFSET    #{skipped}"                        unless skipped.blank?     )
      ].compact.join("\n")
    end


    def inclusion_predicate_sql
      "IN"
    end

    def christener
      @christener ||= Sql::Christener.new
    end

  protected

    def select_clauses
      attributes.collect { |a| a.to_sql(Sql::SelectClause.new(self)) }
    end

    def where_clauses
      wheres.collect { |w| w.to_sql(Sql::WhereClause.new(self)) }
    end

    def group_clauses
      groupings.collect { |g| g.to_sql(Sql::GroupClause.new(self)) }
    end

    def order_clauses
      orders.collect { |o| o.to_sql(Sql::OrderClause.new(self)) }
    end

  end
end
