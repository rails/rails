require "cases/helper"

class ActiveRecord::Relation
  class WhereClauseTest < ActiveRecord::TestCase
    test "+ combines two where clauses" do
      first_clause = WhereClause.new([table["id"].eq(bind_param)], [["id", 1]])
      second_clause = WhereClause.new([table["name"].eq(bind_param)], [["name", "Sean"]])
      combined = WhereClause.new(
        [table["id"].eq(bind_param), table["name"].eq(bind_param)],
        [["id", 1], ["name", "Sean"]],
      )

      assert_equal combined, first_clause + second_clause
    end

    test "+ is associative, but not commutative" do
      a = WhereClause.new(["a"], ["bind a"])
      b = WhereClause.new(["b"], ["bind b"])
      c = WhereClause.new(["c"], ["bind c"])

      assert_equal a + (b + c), (a + b) + c
      assert_not_equal a + b, b + a
    end

    test "an empty where clause is the identity value for +" do
      clause = WhereClause.new([table["id"].eq(bind_param)], [["id", 1]])

      assert_equal clause, clause + WhereClause.empty
    end

    private

    def table
      Arel::Table.new("table")
    end

    def bind_param
      Arel::Nodes::BindParam.new
    end
  end
end
