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

    test "merge combines two where clauses" do
      a = WhereClause.new([table["id"].eq(1)], [])
      b = WhereClause.new([table["name"].eq("Sean")], [])
      expected = WhereClause.new([table["id"].eq(1), table["name"].eq("Sean")], [])

      assert_equal expected, a.merge(b)
    end

    test "merge keeps the right side, when two equality clauses reference the same column" do
      a = WhereClause.new([table["id"].eq(1), table["name"].eq("Sean")], [])
      b = WhereClause.new([table["name"].eq("Jim")], [])
      expected = WhereClause.new([table["id"].eq(1), table["name"].eq("Jim")], [])

      assert_equal expected, a.merge(b)
    end

    test "merge removes bind parameters matching overlapping equality clauses" do
      a = WhereClause.new(
        [table["id"].eq(bind_param), table["name"].eq(bind_param)],
        [[column("id"), 1], [column("name"), "Sean"]],
      )
      b = WhereClause.new(
        [table["name"].eq(bind_param)],
        [[column("name"), "Jim"]]
      )
      expected = WhereClause.new(
        [table["id"].eq(bind_param), table["name"].eq(bind_param)],
        [[column("id"), 1], [column("name"), "Jim"]],
      )

      assert_equal expected, a.merge(b)
    end

    test "merge allows for columns with the same name from different tables" do
      skip "This is not possible as of 4.2, and the binds do not yet contain sufficient information for this to happen"
      # We might be able to change the implementation to remove conflicts by index, rather than column name
    end

    test "a clause knows if it is empty" do
      assert WhereClause.empty.empty?
      assert_not WhereClause.new(["anything"], []).empty?
    end

    private

    def table
      Arel::Table.new("table")
    end

    def bind_param
      Arel::Nodes::BindParam.new
    end

    def column(name)
      ActiveRecord::ConnectionAdapters::Column.new(name, nil, nil)
    end
  end
end
