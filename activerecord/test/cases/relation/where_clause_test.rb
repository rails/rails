# frozen_string_literal: true

require "cases/helper"

class ActiveRecord::Relation
  class WhereClauseTest < ActiveRecord::TestCase
    test "+ combines two where clauses" do
      first_clause = WhereClause.new([table["id"].eq(bind_param(1))])
      second_clause = WhereClause.new([table["name"].eq(bind_param("Sean"))])
      combined = WhereClause.new(
        [table["id"].eq(bind_param(1)), table["name"].eq(bind_param("Sean"))],
      )

      assert_equal combined, first_clause + second_clause
    end

    test "+ is associative, but not commutative" do
      a = WhereClause.new(["a"])
      b = WhereClause.new(["b"])
      c = WhereClause.new(["c"])

      assert_equal a + (b + c), (a + b) + c
      assert_not_equal a + b, b + a
    end

    test "an empty where clause is the identity value for +" do
      clause = WhereClause.new([table["id"].eq(bind_param(1))])

      assert_equal clause, clause + WhereClause.empty
    end

    test "merge combines two where clauses" do
      a = WhereClause.new([table["id"].eq(1)])
      b = WhereClause.new([table["name"].eq("Sean")])
      expected = WhereClause.new([table["id"].eq(1), table["name"].eq("Sean")])

      assert_equal expected, a.merge(b)
    end

    test "merge keeps the right side, when two equality clauses reference the same column" do
      a = WhereClause.new([table["id"].eq(1), table["name"].eq("Sean")])
      b = WhereClause.new([table["name"].eq("Jim")])
      expected = WhereClause.new([table["id"].eq(1), table["name"].eq("Jim")])

      assert_equal expected, a.merge(b)
    end

    test "merge removes bind parameters matching overlapping equality clauses" do
      a = WhereClause.new(
        [table["id"].eq(bind_param(1)), table["name"].eq(bind_param("Sean"))],
      )
      b = WhereClause.new(
        [table["name"].eq(bind_param("Jim"))],
      )
      expected = WhereClause.new(
        [table["id"].eq(bind_param(1)), table["name"].eq(bind_param("Jim"))],
      )

      assert_equal expected, a.merge(b)
    end

    test "merge allows for columns with the same name from different tables" do
      table2 = Arel::Table.new("table2")
      a = WhereClause.new(
        [table["id"].eq(bind_param(1)), table2["id"].eq(bind_param(2))],
      )
      b = WhereClause.new(
        [table["id"].eq(bind_param(3))],
      )
      expected = WhereClause.new(
        [table2["id"].eq(bind_param(2)), table["id"].eq(bind_param(3))],
      )

      assert_equal expected, a.merge(b)
    end

    test "a clause knows if it is empty" do
      assert_empty WhereClause.empty
      assert_not_empty WhereClause.new(["anything"])
    end

    test "invert cannot handle nil" do
      where_clause = WhereClause.new([nil])

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
      ])
      expected = WhereClause.new([
        table["id"].not_in([1, 2, 3]),
        table["id"].not_eq(1),
        Arel::Nodes::Not.new(Arel::Nodes::SqlLiteral.new("sql literal")),
        Arel::Nodes::Not.new(random_object)
      ])

      assert_equal expected, original.invert
    end

    test "except removes binary predicates referencing a given column" do
      where_clause = WhereClause.new([
        table["id"].in([1, 2, 3]),
        table["name"].eq(bind_param("Sean")),
        table["age"].gteq(bind_param(30)),
      ])
      expected = WhereClause.new([table["age"].gteq(bind_param(30))])

      assert_equal expected, where_clause.except("id", "name")
    end

    test "except jumps over unhandled binds (like with OR) correctly" do
      wcs = (0..9).map do |i|
        WhereClause.new([table["id#{i}"].eq(bind_param(i))])
      end

      wc = wcs[0] + wcs[1] + wcs[2].or(wcs[3]) + wcs[4] + wcs[5] + wcs[6].or(wcs[7]) + wcs[8] + wcs[9]

      expected = wcs[0] + wcs[2].or(wcs[3]) + wcs[5] + wcs[6].or(wcs[7]) + wcs[9]
      actual = wc.except("id1", "id2", "id4", "id7", "id8")

      assert_equal expected, actual
    end

    test "ast groups its predicates with AND" do
      predicates = [
        table["id"].in([1, 2, 3]),
        table["name"].eq(bind_param(nil)),
      ]
      where_clause = WhereClause.new(predicates)
      expected = Arel::Nodes::And.new(predicates)

      assert_equal expected, where_clause.ast
    end

    test "ast wraps any SQL literals in parenthesis" do
      random_object = Object.new
      where_clause = WhereClause.new([
        table["id"].in([1, 2, 3]),
        "foo = bar",
        random_object,
      ])
      expected = Arel::Nodes::And.new([
        table["id"].in([1, 2, 3]),
        Arel::Nodes::Grouping.new(Arel.sql("foo = bar")),
        random_object,
      ])

      assert_equal expected, where_clause.ast
    end

    test "ast removes any empty strings" do
      where_clause = WhereClause.new([table["id"].in([1, 2, 3])])
      where_clause_with_empty = WhereClause.new([table["id"].in([1, 2, 3]), ""])

      assert_equal where_clause.ast, where_clause_with_empty.ast
    end

    test "or joins the two clauses using OR" do
      where_clause = WhereClause.new([table["id"].eq(bind_param(1))])
      other_clause = WhereClause.new([table["name"].eq(bind_param("Sean"))])
      expected_ast =
        Arel::Nodes::Grouping.new(
          Arel::Nodes::Or.new(table["id"].eq(bind_param(1)), table["name"].eq(bind_param("Sean")))
        )

      assert_equal expected_ast.to_sql, where_clause.or(other_clause).ast.to_sql
    end

    test "or returns an empty where clause when either side is empty" do
      where_clause = WhereClause.new([table["id"].eq(bind_param(1))])

      assert_equal WhereClause.empty, where_clause.or(WhereClause.empty)
      assert_equal WhereClause.empty, WhereClause.empty.or(where_clause)
    end

    test "or places common conditions before the OR" do
      a = WhereClause.new(
        [table["id"].eq(bind_param(1)), table["name"].eq(bind_param("Sean"))],
      )
      b = WhereClause.new(
        [table["id"].eq(bind_param(1)), table["hair_color"].eq(bind_param("black"))],
      )

      common = WhereClause.new(
        [table["id"].eq(bind_param(1))],
      )

      or_clause = WhereClause.new([table["name"].eq(bind_param("Sean"))])
        .or(WhereClause.new([table["hair_color"].eq(bind_param("black"))]))

      assert_equal common + or_clause, a.or(b)
    end

    test "or can detect identical or as being a common condition" do
      common_or = WhereClause.new([table["name"].eq(bind_param("Sean"))])
        .or(WhereClause.new([table["hair_color"].eq(bind_param("black"))]))

      a = common_or + WhereClause.new([table["id"].eq(bind_param(1))])
      b = common_or + WhereClause.new([table["foo"].eq(bind_param("bar"))])

      new_or = WhereClause.new([table["id"].eq(bind_param(1))])
        .or(WhereClause.new([table["foo"].eq(bind_param("bar"))]))

      assert_equal common_or + new_or, a.or(b)
    end

    test "or will use only common conditions if one side only has common conditions" do
      only_common = WhereClause.new([
        table["id"].eq(bind_param(1)),
        "foo = bar",
      ])

      common_with_extra = WhereClause.new([
        table["id"].eq(bind_param(1)),
        "foo = bar",
        table["extra"].eq(bind_param("pluto")),
      ])

      assert_equal only_common, only_common.or(common_with_extra)
      assert_equal only_common, common_with_extra.or(only_common)
    end

    private

      def table
        Arel::Table.new("table")
      end

      def bind_param(value)
        Arel::Nodes::BindParam.new(value)
      end
  end
end
