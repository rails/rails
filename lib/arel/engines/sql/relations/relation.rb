module Arel
  class Relation

    def compiler
      @compiler ||= "Arel::SqlCompiler::#{engine.adapter_name}Compiler".constantize.new(self)
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
  end
end
