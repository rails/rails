module Arel
  class Relation
    @@tables_primary_keys = {}

    def compiler
      @compiler ||=  begin
        "Arel::SqlCompiler::#{engine.adapter_name}Compiler".constantize.new(self)
      rescue
        Arel::SqlCompiler::GenericCompiler.new(self)
      end
    end

    def to_sql(formatter = Sql::SelectStatement.new(self))
      formatter.select compiler.select_sql, self
    end

    def christener
      @christener ||= Sql::Christener.new
    end

    def inclusion_predicate_sql
      "IN"
    end

    def primary_key
      if @@tables_primary_keys.has_key?(table.name)
        @@tables_primary_keys[table.name]
      else
        @@tables_primary_keys[table.name] = engine.primary_key(table.name)
      end
    end

    protected

      def from_clauses
        sources.blank? ? table_sql(Sql::TableReference.new(self)) : sources
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

      def having_clauses
        havings.collect { |g| g.to_sql(Sql::HavingClause.new(self)) }
      end

      def order_clauses
        orders.collect { |o| o.to_sql(Sql::OrderClause.new(self)) }
      end
  end
end
