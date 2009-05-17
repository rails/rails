module Arel
  class Relation
    def to_sql(formatter = Sql::SelectStatement.new(self))
      formatter.select select_sql, self
    end

    def select_sql
      [
        "SELECT     #{attributes.collect { |a| a.to_sql(Sql::SelectClause.new(self)) }.join(', ')}",
        "FROM       #{table_sql(Sql::TableReference.new(self))}",
        (joins(self)                                                                                    unless joins(self).blank? ),
        ("WHERE     #{wheres   .collect { |w| w.to_sql(Sql::WhereClause.new(self)) }.join("\n\tAND ")}" unless wheres.blank?      ),
        ("GROUP BY  #{groupings.collect { |g| g.to_sql(Sql::GroupClause.new(self)) }.join(', ')}"       unless groupings.blank?   ),
        ("ORDER BY  #{orders   .collect { |o| o.to_sql(Sql::OrderClause.new(self)) }.join(', ')}"       unless orders.blank?      ),
        ("LIMIT     #{taken}"                                                                           unless taken.blank?       ),
        ("OFFSET    #{skipped}"                                                                         unless skipped.blank?     )
      ].compact.join("\n")
    end

    def inclusion_predicate_sql
      "IN"
    end

    def christener
      @christener ||= Sql::Christener.new
    end
  end
end
