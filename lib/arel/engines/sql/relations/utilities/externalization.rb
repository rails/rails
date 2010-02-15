module Arel
  class Externalization < Compound
    include Recursion::BaseCase

    def table_sql(formatter = Sql::TableReference.new(relation))
      formatter.select relation.compiler.select_sql, self
    end

    # REMOVEME
    def name
      relation.name + '_external'
    end
  end
end
