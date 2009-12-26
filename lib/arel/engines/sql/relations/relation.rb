module Arel
  class Relation
    def to_sql(formatter = Sql::SelectStatement.new(self))
      formatter.select select_sql, self
    end

    def select_sql
      if engine.adapter_name == "PostgreSQL" && !orders.blank? && using_distinct_on?
        # PostgreSQL does not allow arbitrary ordering when using DISTINCT ON, so we work around this
        # by wrapping the +sql+ string as a sub-select and ordering in that query.
        order = order_clauses.join(', ').split(',').map { |s| s.strip }.reject(&:blank?)
        order = order.zip((0...order.size).to_a).map { |s,i| "id_list.alias_#{i} #{'DESC' if s =~ /\bdesc$/i}" }.join(', ')

        query = build_query \
          "SELECT     #{select_clauses.kind_of?(::Array) ? select_clauses.join("") : select_clauses.to_s}",
          "FROM       #{table_sql(Sql::TableReference.new(self))}",
          (joins(self)                                   unless joins(self).blank? ),
          ("WHERE     #{where_clauses.join("\n\tAND ")}" unless wheres.blank?      ),
          ("GROUP BY  #{group_clauses.join(', ')}"       unless groupings.blank?   )

        build_query \
          "SELECT * FROM (#{query}) AS id_list",
          "ORDER BY #{order}",
          ("LIMIT     #{taken}"                          unless taken.blank?       ),
          ("OFFSET    #{skipped}"                        unless skipped.blank?     )

      else
        build_query \
          "SELECT     #{select_clauses.join(', ')}",
          "FROM       #{table_sql(Sql::TableReference.new(self))}",
          (joins(self)                                   unless joins(self).blank? ),
          ("WHERE     #{where_clauses.join("\n\tAND ")}" unless wheres.blank?      ),
          ("GROUP BY  #{group_clauses.join(', ')}"       unless groupings.blank?   ),
          ("ORDER BY  #{order_clauses.join(', ')}"       unless orders.blank?      ),
          ("LIMIT     #{taken}"                          unless taken.blank?       ),
          ("OFFSET    #{skipped}"                        unless skipped.blank?     )
      end
    end

    def inclusion_predicate_sql
      "IN"
    end

    def christener
      @christener ||= Sql::Christener.new
    end

  protected

    def build_query(*parts)
      parts.compact.join(" ")
    end

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

    def using_distinct_on?
      select_clauses.any? { |x| x =~ /DISTINCT ON/ }
    end
  end
end
