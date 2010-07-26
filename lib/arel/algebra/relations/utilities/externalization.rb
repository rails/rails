module Arel
  class Externalization < Compound
    include Recursion::BaseCase

    def == other
      super || Externalization === other && relation == other.relation
    end

    def wheres
      []
    end

    def attributes
      @attributes ||= Header.new(relation.attributes.map { |a| a.to_attribute(self) })
    end

    def table_sql(formatter = Sql::TableReference.new(relation))
      formatter.select relation.compiler.select_sql, self
    end

    # REMOVEME
    def name
      relation.name + '_external'
    end
  end
end
