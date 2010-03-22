module Arel
  class Compound
    delegate :table, :table_sql, :to => :relation

    def build_query(*parts)
      parts.compact.join(" ")
    end
  end
end

