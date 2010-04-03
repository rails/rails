module Arel
  class Join
    def table_sql(formatter = Sql::TableReference.new(self))
      relation1.externalize.table_sql(formatter)
    end

    def joins(environment, formatter = Sql::TableReference.new(environment))
      @joins ||= begin
        this_join = [
          join_sql,
          relation2.externalize.table_sql(formatter),
          ("ON" unless predicates.blank?),
          (ons + relation2.externalize.wheres).collect { |p| p.bind(environment.relation).to_sql(Sql::WhereClause.new(environment)) }.join(' AND ')
        ].compact.join(" ")
        [relation1.joins(environment), this_join, relation2.joins(environment)].compact.join(" ")
      end
    end
  end

  class InnerJoin < Join
    def join_sql; "INNER JOIN" end
  end

  class OuterJoin < Join
    def join_sql; "LEFT OUTER JOIN" end
  end

  class StringJoin < Join
    def joins(environment, formatter = Sql::TableReference.new(environment))
       [relation1.joins(environment), relation2].compact.join(" ")
    end
  end
end
