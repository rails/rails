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
        [attribute("id", 1), attribute("name", "Sean")],
      )
      b = WhereClause.new(
        [table["name"].eq(bind_param)],
        [attribute("name", "Jim")]
      )
      expected = WhereClause.new(
        [table["id"].eq(bind_param), table["name"].eq(bind_param)],
        [attribute("id", 1), attribute("name", "Jim")],
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

    test "invert cannot handle nil" do
      where_clause = WhereClause.new([nil], [])

      assert_raises ArgumentError do
        where_clause.invert
      end
    end

    test "invert replaces each part of the predicate with its inverse" do
      random_object = Object.new
      original = WhereClause.new([
        table["id"].in([1, 2, 3]),
        table["id"].eq(1),
        "sql literal",
        random_object
      ], [])
      expected = WhereClause.new([
        table["id"].not_in([1, 2, 3]),
        table["id"].not_eq(1),
        Arel::Nodes::Not.new(Arel::Nodes::SqlLiteral.new("sql literal")),
        Arel::Nodes::Not.new(random_object)
      ], [])

      assert_equal expected, original.invert
    end

    test "accept removes binary predicates referencing a given column" do
      where_clause = WhereClause.new([
        table["id"].in([1, 2, 3]),
        table["name"].eq(bind_param),
        table["age"].gteq(bind_param),
      ], [
        attribute("name", "Sean"),
        attribute("age", 30),
      ])
      expected = WhereClause.new([table["age"].gteq(bind_param)], [attribute("age", 30)])

      assert_equal expected, where_clause.except("id", "name")
    end

    test "ast groups its predicates with AND" do
      predicates = [
        table["id"].in([1, 2, 3]),
        table["name"].eq(bind_param),
      ]
      where_clause = WhereClause.new(predicates, [])
      expected = Arel::Nodes::And.new(predicates)

      assert_equal expected, where_clause.ast
    end

    test "ast wraps any SQL literals in parenthesis" do
      random_object = Object.new
      where_clause = WhereClause.new([
        table["id"].in([1, 2, 3]),
        "foo = bar",
        random_object,
      ], [])
      expected = Arel::Nodes::And.new([
        table["id"].in([1, 2, 3]),
        Arel::Nodes::Grouping.new(Arel.sql("foo = bar")),
        Arel::Nodes::Grouping.new(random_object),
      ])

      assert_equal expected, where_clause.ast
    end

    test "ast removes any empty strings" do
      where_clause = WhereClause.new([table["id"].in([1, 2, 3])], [])
      where_clause_with_empty = WhereClause.new([table["id"].in([1, 2, 3]), ""], [])

      assert_equal where_clause.ast, where_clause_with_empty.ast
    end

    test "or joins the two clauses using OR" do
      where_clause = WhereClause.new([table["id"].eq(bind_param)], [attribute("id", 1)])
      other_clause = WhereClause.new([table["name"].eq(bind_param)], [attribute("name", "Sean")])
      expected_ast =
        Arel::Nodes::Grouping.new(
          Arel::Nodes::Or.new(table["id"].eq(bind_param), table["name"].eq(bind_param))
        )
      expected_binds = where_clause.binds + other_clause.binds

      assert_equal expected_ast.to_sql, where_clause.or(other_clause).ast.to_sql
      assert_equal expected_binds, where_clause.or(other_clause).binds
    end

    test "or returns an empty where clause when either side is empty" do
      where_clause = WhereClause.new([table["id"].eq(bind_param)], [attribute("id", 1)])

      assert_equal WhereClause.empty, where_clause.or(WhereClause.empty)
      assert_equal WhereClause.empty, WhereClause.empty.or(where_clause)
    end

    private

      def table
        Arel::Table.new("table")
      end

      def bind_param
        Arel::Nodes::BindParam.new
      end

      def attribute(name, value)
        ActiveRecord::Attribute.with_cast_value(name, value, ActiveRecord::Type::Value.new)
      end
  end
end
