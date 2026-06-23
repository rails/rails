# frozen_string_literal: true

require_relative "../helper"
require "bigdecimal"

module Arel
  module Visitors
    class ToSQLTest < Arel::Test
      setup do
        @conn = Table.engine
        @visitor = ToSql.new @conn.lease_connection
        @table = Table.new(:users)
        @attr = @table[:id]
      end

      test "the to_sql visitor works with BindParams" do
        node = Nodes::BindParam.new(1)
        sql = compile node
        assert_like "?", sql
      end

      test "the to_sql visitor does not quote BindParams used as part of a ValuesList" do
        bp = Nodes::BindParam.new(1)
        values = Nodes::ValuesList.new([[bp]])
        sql = compile values
        assert_like "VALUES (?)", sql
      end

      test "the to_sql visitor can define a dispatch method" do
        visited = false
        viz = Class.new(Arel::Visitors::Visitor) {
          define_method(:hello) do |node, c|
            visited = true
          end

          def dispatch
            { Arel::Table => "hello" }
          end
        }.new

        viz.accept(@table, Collectors::SQLString.new)
        assert visited, "hello method was called"
      end

      test "the to_sql visitor should not quote sql literals" do
        node = @table[Arel.star]
        sql = compile node
        assert_like '"users".*', sql
      end

      test "the to_sql visitor should visit named functions" do
        function = Nodes::NamedFunction.new("omg", [Arel.star])
        assert_equal "omg(*)", compile(function)
      end

      test "the to_sql visitor should chain predications on named functions" do
        function = Nodes::NamedFunction.new("omg", [Arel.star])
        sql = compile(function.eq(2))
        assert_like %{ omg(*) = 2 }, sql
      end

      test "the to_sql visitor should handle nil with named functions" do
        function = Nodes::NamedFunction.new("omg", [Arel.star])
        sql = compile(function.eq(nil))
        assert_like %{ omg(*) IS NULL }, sql
      end

      test "the to_sql visitor should mark collector as non-retryable when visiting named function" do
        function = Nodes::NamedFunction.new("ABS", [@table])
        collector = Collectors::SQLString.new
        collector.retryable = true
        @visitor.accept(function, collector)

        assert_equal false, collector.retryable
      end

      test "the to_sql visitor should mark collector as non-retryable when visiting SQL literal" do
        node = Nodes::SqlLiteral.new("COUNT(*)")
        collector = Collectors::SQLString.new
        collector.retryable = true
        @visitor.accept(node, collector)

        assert_equal false, collector.retryable
      end

      test "the to_sql visitor should not change retryable if SQL literal is marked as retryable" do
        node = Nodes::SqlLiteral.new("COUNT(*)", retryable: true)
        collector = Collectors::SQLString.new
        collector.retryable = true
        @visitor.accept(node, collector)

        assert_predicate collector, :retryable
      end

      test "the to_sql visitor should mark collector as non-retryable if SQL literal is not retryable" do
        node = Nodes::As.new(
          Nodes::SqlLiteral.new("`product.id`"),
          Nodes::SqlLiteral.new("`product.id`", retryable: true)
        )
        collector = Collectors::SQLString.new
        collector.retryable = true
        @visitor.accept(node, collector)

        assert_equal false, collector.retryable
      end

      test "the to_sql visitor should mark collector as non-retryable when visiting bound SQL literal" do
        node = Nodes::BoundSqlLiteral.new("id IN (?)", [[1, 2, 3]], {})
        collector = Collectors::SQLString.new
        collector.retryable = true
        @visitor.accept(node, collector)

        assert_equal false, collector.retryable
      end

      test "the to_sql visitor should mark collector as non-retryable when visiting insert statement node" do
        statement = Arel::Nodes::InsertStatement.new(@table)
        collector = Collectors::SQLString.new
        collector.retryable = true
        @visitor.accept(statement, collector)

        assert_equal false, collector.retryable
      end

      test "the to_sql visitor should mark collector as non-retryable when visiting update statement node" do
        statement = Arel::Nodes::UpdateStatement.new(@table)
        collector = Collectors::SQLString.new
        collector.retryable = true
        @visitor.accept(statement, collector)

        assert_equal false, collector.retryable
      end

      test "the to_sql visitor should mark collector as non-retryable when visiting delete statement node" do
        statement = Arel::Nodes::DeleteStatement.new(@table)
        collector = Collectors::SQLString.new
        collector.retryable = true
        @visitor.accept(statement, collector)

        assert_equal false, collector.retryable
      end

      test "the to_sql visitor should visit built-in functions" do
        function = Nodes::Count.new([Arel.star])
        assert_equal "COUNT(*)", compile(function)

        function = Nodes::Sum.new([Arel.star])
        assert_equal "SUM(*)", compile(function)

        function = Nodes::Max.new([Arel.star])
        assert_equal "MAX(*)", compile(function)

        function = Nodes::Min.new([Arel.star])
        assert_equal "MIN(*)", compile(function)

        function = Nodes::Avg.new([Arel.star])
        assert_equal "AVG(*)", compile(function)
      end

      test "the to_sql visitor should visit built-in functions operating on distinct values" do
        function = Nodes::Count.new([Arel.star])
        function.distinct = true
        assert_equal "COUNT(DISTINCT *)", compile(function)

        function = Nodes::Sum.new([Arel.star])
        function.distinct = true
        assert_equal "SUM(DISTINCT *)", compile(function)

        function = Nodes::Max.new([Arel.star])
        function.distinct = true
        assert_equal "MAX(DISTINCT *)", compile(function)

        function = Nodes::Min.new([Arel.star])
        function.distinct = true
        assert_equal "MIN(DISTINCT *)", compile(function)

        function = Nodes::Avg.new([Arel.star])
        function.distinct = true
        assert_equal "AVG(DISTINCT *)", compile(function)
      end

      test "the to_sql visitor works with lists" do
        function = Nodes::NamedFunction.new("omg", [Arel.star, Arel.star])
        assert_equal "omg(*, *)", compile(function)
      end

      test "Nodes::Equality should escape strings" do
        test = Table.new(:users)[:name].eq "Aaron Patterson"
        assert_like %{
          "users"."name" = 'Aaron Patterson'
        }, compile(test)
      end

      test "Nodes::Equality should handle false" do
        table = Table.new(:users)
        val = Nodes.build_quoted(false, table[:active])
        sql = compile Nodes::Equality.new(val, val)
        assert_like %{ 'f' = 'f' }, sql
      end

      test "Nodes::Equality should handle nil" do
        sql = compile Nodes::Equality.new(@table[:name], nil)
        assert_like %{ "users"."name" IS NULL }, sql
      end

      test "Nodes::Grouping wraps nested groupings in brackets only once" do
        sql = compile Nodes::Grouping.new(Nodes::Grouping.new(Nodes.build_quoted("foo")))
        assert_equal "('foo')", sql
      end

      test "Nodes::NotEqual should handle false" do
        val = Nodes.build_quoted(false, @table[:active])
        sql = compile Nodes::NotEqual.new(@table[:active], val)
        assert_like %{ "users"."active" != 'f' }, sql
      end

      test "Nodes::NotEqual should handle nil" do
        val = Nodes.build_quoted(nil, @table[:active])
        sql = compile Nodes::NotEqual.new(@table[:name], val)
        assert_like %{ "users"."name" IS NOT NULL }, sql
      end

      test "Nodes::IsNotDistinctFrom should construct a valid generic SQL statement" do
        test = Table.new(:users)[:name].is_not_distinct_from "Aaron Patterson"
        assert_like %{
          CASE WHEN "users"."name" = 'Aaron Patterson' OR ("users"."name" IS NULL AND 'Aaron Patterson' IS NULL) THEN 0 ELSE 1 END = 0
        }, compile(test)
      end

      test "Nodes::IsNotDistinctFrom should handle column names on both sides" do
        test = Table.new(:users)[:first_name].is_not_distinct_from Table.new(:users)[:last_name]
        assert_like %{
          CASE WHEN "users"."first_name" = "users"."last_name" OR ("users"."first_name" IS NULL AND "users"."last_name" IS NULL) THEN 0 ELSE 1 END = 0
        }, compile(test)
      end

      test "Nodes::IsNotDistinctFrom should handle nil" do
        val = Nodes.build_quoted(nil, @table[:active])
        sql = compile Nodes::IsNotDistinctFrom.new(@table[:name], val)
        assert_like %{ "users"."name" IS NULL }, sql
      end

      test "Nodes::IsDistinctFrom should handle column names on both sides" do
        test = Table.new(:users)[:first_name].is_distinct_from Table.new(:users)[:last_name]
        assert_like %{
          CASE WHEN "users"."first_name" = "users"."last_name" OR ("users"."first_name" IS NULL AND "users"."last_name" IS NULL) THEN 0 ELSE 1 END = 1
        }, compile(test)
      end

      test "Nodes::IsDistinctFrom should handle nil" do
        val = Nodes.build_quoted(nil, @table[:active])
        sql = compile Nodes::IsDistinctFrom.new(@table[:name], val)
        assert_like %{ "users"."name" IS NOT NULL }, sql
      end

      test "should visit string subclass" do
        [
          Class.new(String).new(":'("),
          Class.new(Class.new(String)).new(":'("),
        ].each do |obj|
          val = Nodes.build_quoted(obj, @table[:active])
          sql = compile Nodes::NotEqual.new(@table[:name], val)
          assert_like %{ "users"."name" != ':\\'(' }, sql
        end
      end

      test "should visit_Class" do
        assert_equal "'DateTime'", compile(Nodes.build_quoted(DateTime))
      end

      test "should escape LIMIT" do
        sc = Arel::Nodes::SelectStatement.new
        sc.limit = Arel::Nodes::Limit.new(Nodes.build_quoted("omg"))
        assert_match(/LIMIT 'omg'/, compile(sc))
      end

      test "should contain a single space before ORDER BY" do
        table = Table.new(:users)
        test = table.order(table[:name])
        sql = compile test
        assert_match(/"users" ORDER BY/, sql)
      end

      test "should quote LIMIT without column type coercion" do
        table = Table.new(:users)
        sc = table.where(table[:name].eq(0)).take(1).ast
        assert_match(/WHERE "users"."name" = 0 LIMIT 1/, compile(sc))
      end

      test "should visit_DateTime" do
        dt = DateTime.now
        table = Table.new(:users)
        test = table[:created_at].eq dt
        sql = compile test

        assert_like %{"users"."created_at" = '#{dt.strftime("%Y-%m-%d %H:%M:%S")}'}, sql
      end

      test "should visit_Float" do
        test = Table.new(:products)[:price].eq 2.14
        sql = compile test
        assert_like %{"products"."price" = 2.14}, sql
      end

      test "should visit_Not" do
        sql = compile Nodes::Not.new(Arel.sql("foo"))
        assert_like "NOT (foo)", sql
      end

      test "should apply Not to the whole expression" do
        node = Nodes::And.new [@attr.eq(10), @attr.eq(11)]
        sql = compile Nodes::Not.new(node)
        assert_like %{NOT ("users"."id" = 10 AND "users"."id" = 11)}, sql
      end

      test "should visit_As" do
        as = Nodes::As.new(Arel.sql("foo"), Arel.sql("bar"))
        sql = compile as
        assert_like "foo AS bar", sql
      end

      test "should visit_Integer" do
        assert_equal "8787878092", compile(8787878092)
      end

      test "should visit_Hash" do
        assert_equal "'#{{ a: 1 }.inspect}'", compile(Nodes.build_quoted(a: 1))
      end

      test "should visit_Set" do
        assert_equal "1, 2", compile(Set.new([1, 2]))
      end

      test "should visit_BigDecimal" do
        assert_equal BigDecimal("2.14").to_s, compile(Nodes.build_quoted(BigDecimal("2.14")))
      end

      test "should visit_Date" do
        dt = Date.today
        table = Table.new(:users)
        test = table[:created_at].eq dt
        sql = compile test

        assert_like %{"users"."created_at" = '#{dt.strftime("%Y-%m-%d")}'}, sql
      end

      test "should visit_NilClass" do
        assert_like "NULL", compile(Nodes.build_quoted(nil))
      end

      test "unsupported input should raise UnsupportedVisitError" do
        error = assert_raises(UnsupportedVisitError) { compile(nil) }
        assert_match(/\AUnsupported/, error.message)
      end

      test "should visit_Arel_SelectManager, which is a subquery" do
        mgr = Table.new(:foo).project(:bar)
        assert_like '(SELECT bar FROM "foo")', compile(mgr)
      end

      test "should visit_Arel_Nodes_And" do
        node = Nodes::And.new [@attr.eq(10), @attr.eq(11)]
        assert_like %{
          "users"."id" = 10 AND "users"."id" = 11
        }, compile(node)
      end

      test "should visit_Arel_Nodes_Or" do
        node = Nodes::Or.new [@attr.eq(10), @attr.eq(11)]
        assert_like %{
          "users"."id" = 10 OR "users"."id" = 11
        }, compile(node)
      end

      test "should visit_Arel_Nodes_Assignment" do
        column = @table["id"]
        node = Nodes::Assignment.new(
          Nodes::UnqualifiedColumn.new(column),
          Nodes::UnqualifiedColumn.new(column)
        )
        assert_like %{
          "id" = "id"
        }, compile(node)
      end

      test "should visit_TrueClass" do
        test = Table.new(:users)[:bool].eq(true)
        assert_like %{ "users"."bool" = 't' }, compile(test)
      end

      test "Nodes::Matches should know how to visit" do
        node = @table[:name].matches("foo%")
        assert_like %{
          "users"."name" LIKE 'foo%'
        }, compile(node)
      end

      test "Nodes::Matches can handle ESCAPE" do
        node = @table[:name].matches("foo!%", "!")
        assert_like %{
          "users"."name" LIKE 'foo!%' ESCAPE '!'
        }, compile(node)
      end

      test "Nodes::Matches can handle subqueries" do
        subquery = @table.project(:id).where(@table[:name].matches("foo%"))
        node = @attr.in subquery
        assert_like %{
          "users"."id" IN (SELECT id FROM "users" WHERE "users"."name" LIKE 'foo%')
        }, compile(node)
      end

      test "Nodes::DoesNotMatch should know how to visit" do
        node = @table[:name].does_not_match("foo%")
        assert_like %{
          "users"."name" NOT LIKE 'foo%'
        }, compile(node)
      end

      test "Nodes::DoesNotMatch can handle ESCAPE" do
        node = @table[:name].does_not_match("foo!%", "!")
        assert_like %{
          "users"."name" NOT LIKE 'foo!%' ESCAPE '!'
        }, compile(node)
      end

      test "Nodes::DoesNotMatch can handle subqueries" do
        subquery = @table.project(:id).where(@table[:name].does_not_match("foo%"))
        node = @attr.in subquery
        assert_like %{
          "users"."id" IN (SELECT id FROM "users" WHERE "users"."name" NOT LIKE 'foo%')
        }, compile(node)
      end

      test "Nodes::Ordering should know how to visit" do
        node = @attr.desc
        assert_like %{
          "users"."id" DESC
        }, compile(node)
      end

      test "Nodes::Ordering should handle nulls first" do
        node = @attr.desc.nulls_first
        assert_like %{
          "users"."id" DESC NULLS FIRST
        }, compile(node)
      end

      test "Nodes::Ordering should handle nulls last" do
        node = @attr.desc.nulls_last
        assert_like %{
          "users"."id" DESC NULLS LAST
        }, compile(node)
      end

      test "Nodes::Ordering should handle nulls first reversed" do
        node = @attr.desc.nulls_first.reverse
        assert_like %{
          "users"."id" ASC NULLS LAST
        }, compile(node)
      end

      test "Nodes::Ordering should handle nulls last reversed" do
        node = @attr.desc.nulls_last.reverse
        assert_like %{
          "users"."id" ASC NULLS FIRST
        }, compile(node)
      end

      test "Nodes::In should know how to visit" do
        node = @attr.in [1, 2, 3]
        assert_like %{
          "users"."id" IN (1, 2, 3)
        }, compile(node)
      end

      test "Nodes::In should return 1=0 when empty right which is always false" do
        node = @attr.in []
        assert_equal "1=0", compile(node)
      end

      test "Nodes::In can handle two dot ranges" do
        node = @attr.between 1..3
        assert_like %{
          "users"."id" BETWEEN 1 AND 3
        }, compile(node)
      end

      test "Nodes::In can handle three dot ranges" do
        node = @attr.between 1...3
        assert_like %{
          "users"."id" >= 1 AND "users"."id" < 3
        }, compile(node)
      end

      test "Nodes::In can handle ranges bounded by infinity" do
        node = @attr.between 1..Float::INFINITY
        assert_like %{
          "users"."id" >= 1
        }, compile(node)

        node = @attr.between(-Float::INFINITY..3)
        assert_like %{
          "users"."id" <= 3
        }, compile(node)

        node = @attr.between(-Float::INFINITY...3)
        assert_like %{
          "users"."id" < 3
        }, compile(node)

        node = @attr.between(-Float::INFINITY..Float::INFINITY)
        assert_like %{1=1}, compile(node)
      end

      test "Nodes::In can handle subqueries" do
        table = Table.new(:users)
        subquery = table.project(:id).where(table[:name].eq("Aaron"))
        node = @attr.in subquery
        assert_like %{
          "users"."id" IN (SELECT id FROM "users" WHERE "users"."name" = 'Aaron')
        }, compile(node)
      end

      test "Nodes::In is not preparable when an array" do
        node = @attr.in [1, 2, 3]

        collector = Collectors::SQLString.new.tap { |c| c.preparable = true }
        @visitor.accept(node, collector)
        assert_equal false, collector.preparable
      end

      test "Nodes::In is preparable when a subselect" do
        table = Table.new(:users)
        subquery = table.project(table[:id]).where(table[:name].eq("Aaron"))
        node = @attr.in subquery

        collector = Collectors::SQLString.new.tap { |c| c.preparable = true }
        @visitor.accept(node, collector)
        assert_equal true, collector.preparable
      end

      test "Nodes::InfixOperation should handle Multiplication" do
        node = Arel::Attribute.new(Table.new(:products), :price) * Arel::Attribute.new(Table.new(:currency_rates), :rate)
        assert_equal %("products"."price" * "currency_rates"."rate"), compile(node)
      end

      test "Nodes::InfixOperation should handle Division" do
        node = Arel::Attribute.new(Table.new(:products), :price) / 5
        assert_equal %("products"."price" / 5), compile(node)
      end

      test "Nodes::InfixOperation should handle Addition" do
        node = Arel::Attribute.new(Table.new(:products), :price) + 6
        assert_equal %(("products"."price" + 6)), compile(node)
      end

      test "Nodes::InfixOperation should handle Subtraction" do
        node = Arel::Attribute.new(Table.new(:products), :price) - 7
        assert_equal %(("products"."price" - 7)), compile(node)
      end

      test "Nodes::InfixOperation should handle Concatenation" do
        table = Table.new(:users)
        node = table[:name].concat(table[:name])
        assert_equal %("users"."name" || "users"."name"), compile(node)
      end

      test "Nodes::InfixOperation should handle Contains" do
        table = Table.new(:users)
        node = table[:name].contains(table[:name])
        assert_equal %("users"."name" @> "users"."name"), compile(node)
      end

      test "Nodes::InfixOperation should handle Overlaps" do
        table = Table.new(:users)
        node = table[:name].overlaps(table[:name])
        assert_equal %("users"."name" && "users"."name"), compile(node)
      end

      test "Nodes::InfixOperation should handle BitwiseAnd" do
        node = Arel::Attribute.new(Table.new(:products), :bitmap) & 16
        assert_equal %(("products"."bitmap" & 16)), compile(node)
      end

      test "Nodes::InfixOperation should handle BitwiseOr" do
        node = Arel::Attribute.new(Table.new(:products), :bitmap) | 16
        assert_equal %(("products"."bitmap" | 16)), compile(node)
      end

      test "Nodes::InfixOperation should handle BitwiseXor" do
        node = Arel::Attribute.new(Table.new(:products), :bitmap) ^ 16
        assert_equal %(("products"."bitmap" ^ 16)), compile(node)
      end

      test "Nodes::InfixOperation should handle BitwiseShiftLeft" do
        node = Arel::Attribute.new(Table.new(:products), :bitmap) << 4
        assert_equal %(("products"."bitmap" << 4)), compile(node)
      end

      test "Nodes::InfixOperation should handle BitwiseShiftRight" do
        node = Arel::Attribute.new(Table.new(:products), :bitmap) >> 4
        assert_equal %(("products"."bitmap" >> 4)), compile(node)
      end

      test "Nodes::InfixOperation should handle arbitrary operators" do
        node = Arel::Nodes::InfixOperation.new(
          "&&",
          Arel::Attribute.new(Table.new(:products), :name),
          Arel::Attribute.new(Table.new(:products), :name)
        )
        assert_equal %("products"."name" && "products"."name"), compile(node)
      end

      test "Nodes::UnaryOperation should handle BitwiseNot" do
        node = ~ Arel::Attribute.new(Table.new(:products), :bitmap)
        assert_equal %( ~ "products"."bitmap"), compile(node)
      end

      test "Nodes::UnaryOperation should handle arbitrary operators" do
        node = Arel::Nodes::UnaryOperation.new("!", Arel::Attribute.new(Table.new(:products), :active))
        assert_equal %( ! "products"."active"), compile(node)
      end

      test "Nodes::Union squashes parenthesis on multiple unions" do
        subnode = Nodes::Union.new Arel.sql("left"), Arel.sql("right")
        node = Nodes::Union.new subnode, Arel.sql("topright")
        assert_equal "( left UNION right UNION topright )", compile(node)

        subnode = Nodes::Union.new Arel.sql("left"), Arel.sql("right")
        node = Nodes::Union.new Arel.sql("topleft"), subnode
        assert_equal "( topleft UNION left UNION right )", compile(node)
      end

      test "Nodes::Union encloses SELECT statements with parentheses" do
        table = Table.new(:users)
        left = table.where(table[:name].eq(0)).take(1).ast
        right = table.where(table[:name].eq(1)).take(1).ast
        node = Nodes::Union.new left, right
        assert_match(/LIMIT 1\) UNION \(/, compile(node))
      end

      test "Nodes::UnionAll squashes parenthesis on multiple union alls" do
        subnode = Nodes::UnionAll.new Arel.sql("left"), Arel.sql("right")
        node = Nodes::UnionAll.new subnode, Arel.sql("topright")
        assert_equal "( left UNION ALL right UNION ALL topright )", compile(node)

        subnode = Nodes::UnionAll.new Arel.sql("left"), Arel.sql("right")
        node = Nodes::UnionAll.new Arel.sql("topleft"), subnode
        assert_equal "( topleft UNION ALL left UNION ALL right )", compile(node)
      end

      test "Nodes::UnionAll encloses SELECT statements with parentheses" do
        table = Table.new(:users)
        left = table.where(table[:name].eq(0)).take(1).ast
        right = table.where(table[:name].eq(1)).take(1).ast
        node = Nodes::UnionAll.new left, right
        assert_match(/LIMIT 1\) UNION ALL \(/, compile(node))
      end

      test "Nodes::NotIn should know how to visit" do
        node = @attr.not_in [1, 2, 3]
        assert_like %{
          "users"."id" NOT IN (1, 2, 3)
        }, compile(node)
      end

      test "Nodes::NotIn should return 1=1 when empty right which is always true" do
        node = @attr.not_in []
        assert_equal "1=1", compile(node)
      end

      test "Nodes::NotIn can handle two dot ranges" do
        node = @attr.not_between 1..3
        assert_equal %{("users"."id" < 1 OR "users"."id" > 3)}, compile(node)
      end

      test "Nodes::NotIn can handle three dot ranges" do
        node = @attr.not_between 1...3
        assert_equal %{("users"."id" < 1 OR "users"."id" >= 3)}, compile(node)
      end

      test "Nodes::NotIn can handle ranges bounded by infinity" do
        node = @attr.not_between 1..Float::INFINITY
        assert_like %{
          "users"."id" < 1
        }, compile(node)

        node = @attr.not_between(-Float::INFINITY..3)
        assert_like %{
          "users"."id" > 3
        }, compile(node)

        node = @attr.not_between(-Float::INFINITY...3)
        assert_like %{
          "users"."id" >= 3
        }, compile(node)

        node = @attr.not_between(-Float::INFINITY..Float::INFINITY)
        assert_like %{1=0}, compile(node)
      end

      test "Nodes::NotIn can handle subqueries" do
        table = Table.new(:users)
        subquery = table.project(:id).where(table[:name].eq("Aaron"))
        node = @attr.not_in subquery
        assert_like %{
          "users"."id" NOT IN (SELECT id FROM "users" WHERE "users"."name" = 'Aaron')
        }, compile(node)
      end

      test "Nodes::NotIn is not preparable when an array" do
        node = @attr.not_in [1, 2, 3]

        collector = Collectors::SQLString.new.tap { |c| c.preparable = true }
        @visitor.accept(node, collector)
        assert_equal false, collector.preparable
      end

      test "Nodes::NotIn is preparable when a subselect" do
        table = Table.new(:users)
        subquery = table.project(table[:id]).where(table[:name].eq("Aaron"))
        node = @attr.not_in subquery

        collector = Collectors::SQLString.new.tap { |c| c.preparable = true }
        @visitor.accept(node, collector)
        assert_equal true, collector.preparable
      end

      test "Constants should handle true" do
        test = Table.new(:users).create_true
        assert_like %{
          TRUE
        }, compile(test)
      end

      test "Constants should handle false" do
        test = Table.new(:users).create_false
        assert_like %{
          FALSE
        }, compile(test)
      end

      test "Nodes::BoundSqlLiteral works with positional binds" do
        node = Nodes::BoundSqlLiteral.new("id = ?", [1], {})
        assert_like %{
          id = ?
        }, compile(node)
      end

      test "Nodes::BoundSqlLiteral works with named binds" do
        node = Nodes::BoundSqlLiteral.new("id = :id", [], { id: 1 })
        assert_like %{
          id = ?
        }, compile(node)
      end

      test "Nodes::BoundSqlLiteral will only consider named binds starting with a letter" do
        node = Nodes::BoundSqlLiteral.new("id = :0abc", [], { "0abc": 1 })
        assert_like %{
          id = :0abc
        }, compile(node)
      end

      test "Nodes::BoundSqlLiteral works with array values" do
        node = Nodes::BoundSqlLiteral.new("id IN (?)", [[1, 2, 3]], {})
        assert_like %{
          id IN (?, ?, ?)
        }, compile(node)
      end

      test "Nodes::BoundSqlLiteral refuses mixed binds" do
        assert_raises(Arel::BindError) do
          Nodes::BoundSqlLiteral.new("id = ? AND name = :name", [1], { name: "Aaron" })
        end
      end

      test "Nodes::BoundSqlLiteral requires positional binds to match the placeholders" do
        assert_raises(Arel::BindError) do
          Nodes::BoundSqlLiteral.new("id IN (?, ?, ?)", [1, 2], {})
        end

        assert_raises(Arel::BindError) do
          Nodes::BoundSqlLiteral.new("id IN (?, ?, ?)", [1, 2, 3, 4], {})
        end
      end

      test "Nodes::BoundSqlLiteral requires all named bind params to be supplied" do
        assert_raises(Arel::BindError) do
          Nodes::BoundSqlLiteral.new("id IN (:foo, :bar)", [], { foo: 1 })
        end
      end

      test "Nodes::BoundSqlLiteral ignores excess named parameters" do
        node = Nodes::BoundSqlLiteral.new("id = :id", [], { foo: 2, id: 1, bar: 3 })
        assert_like %{
          id = ?
        }, compile(node)
      end

      test "Nodes::BoundSqlLiteral quotes nested arrays" do
        # Two cases to exercise all branches.
        # For real adapters, quoting arrays may fail in adapter-specific ways.

        inner_literal = Nodes::BoundSqlLiteral.new("? * 2", [4], {})
        node = Nodes::BoundSqlLiteral.new("id IN (?)", [[1, [2, 3], inner_literal]], {})
        assert_like %{
          id IN (?, ?, ? * 2)
        }, compile(node)

        node = Nodes::BoundSqlLiteral.new("id IN (?)", [[1, [2, 3]]], {})
        assert_like %{
          id IN (?, ?)
        }, compile(node)
      end

      test "Nodes::BoundSqlLiteral supports other bound literals as binds" do
        node = Arel.sql("?", [1, 2, Arel.sql("?", 3)])
        assert_like %{
          ?, ?, ?
        }, compile(node)
      end

      test "Table should compile node names" do
        test = Table.new(:users).alias("zomgusers")[:id].eq "3"
        assert_like %{
          "zomgusers"."id" = '3'
        }, compile(test)
      end

      test "Table should compile literal SQL" do
        test = Table.new Arel.sql("generate_series(4, 2)")
        assert_like %{ generate_series(4, 2) }, compile(test)
      end

      test "Table should compile Arel nodes" do
        test = Arel::Nodes::NamedFunction.new("generate_series", [4, 2])
        assert_like %{ generate_series(4, 2) }, compile(test)
      end

      test "Table should compile nodes with bind params" do
        bp = Nodes::BindParam.new(1)
        test = Arel::Nodes::NamedFunction.new("generate_series", [4, bp])
        assert_like %{ generate_series(4, ?) }, compile(test)
      end

      test "TableAlias should use the underlying table for checking columns" do
        test = Table.new(:users).alias("zomgusers")[:id].eq "3"
        assert_like %{
          "zomgusers"."id" = '3'
        }, compile(test)
      end

      test "distinct on raises not implemented error" do
        core = Arel::Nodes::SelectCore.new
        core.set_quantifier = Arel::Nodes::DistinctOn.new(Arel.sql("aaron"))

        assert_raises(NotImplementedError) do
          compile(core)
        end
      end

      test "Nodes::Regexp raises not implemented error" do
        node = Arel::Nodes::Regexp.new(@table[:name], Nodes.build_quoted("foo%"))

        assert_raises(NotImplementedError) do
          compile(node)
        end
      end

      test "Nodes::NotRegexp raises not implemented error" do
        node = Arel::Nodes::NotRegexp.new(@table[:name], Nodes.build_quoted("foo%"))

        assert_raises(NotImplementedError) do
          compile(node)
        end
      end

      test "Nodes::Case supports simple case expressions" do
        node = Arel::Nodes::Case.new(@table[:name])
          .when("foo").then(1)
          .else(0)

        assert_like %{
          CASE "users"."name" WHEN 'foo' THEN 1 ELSE 0 END
        }, compile(node)
      end

      test "Nodes::Case supports extended case expressions" do
        node = Arel::Nodes::Case.new
          .when(@table[:name].in(%w(foo bar))).then(1)
          .else(0)

        assert_like %{
          CASE WHEN "users"."name" IN ('foo', 'bar') THEN 1 ELSE 0 END
        }, compile(node)
      end

      test "Nodes::Case works without default branch" do
        node = Arel::Nodes::Case.new(@table[:name])
          .when("foo").then(1)

        assert_like %{
          CASE "users"."name" WHEN 'foo' THEN 1 END
        }, compile(node)
      end

      test "Nodes::Case allows chaining multiple conditions" do
        node = Arel::Nodes::Case.new(@table[:name])
          .when("foo").then(1)
          .when("bar").then(2)
          .else(0)

        assert_like %{
          CASE "users"."name" WHEN 'foo' THEN 1 WHEN 'bar' THEN 2 ELSE 0 END
        }, compile(node)
      end

      test "Nodes::Case supports #when with two arguments and no #then" do
        node = Arel::Nodes::Case.new @table[:name]

        { foo: 1, bar: 0 }.reduce(node) { |case_node, pair| case_node.when(*pair) }

        assert_like %{
          CASE "users"."name" WHEN 'foo' THEN 1 WHEN 'bar' THEN 0 END
        }, compile(node)
      end

      test "Nodes::Case can be chained as a predicate" do
        node = @table[:name].when("foo").then("bar").else("baz")

        assert_like %{
          CASE "users"."name" WHEN 'foo' THEN 'bar' ELSE 'baz' END
        }, compile(node)
      end

      test "Nodes::With handles table aliases" do
        manager = Table.new(:foo).project(Arel.star).from(Arel.sql("expr2"))
        expr1 = Table.new(:bar).project(Arel.star).as("expr1")
        expr2 = Table.new(:baz).project(Arel.star).as("expr2")
        manager.with(expr1, expr2)

        assert_like %{
          WITH expr1 AS (SELECT * FROM "bar"), expr2 AS (SELECT * FROM "baz") SELECT * FROM expr2
        }, compile(manager.ast)
      end

      test "Nodes::With handles Cte nodes" do
        cte = Arel::Nodes::Cte.new("expr1", Table.new(:bar).project(Arel.star))
        manager = Table.new(:foo).
          project(Arel.star).
          with(cte).
          from(cte.to_table).
          where(cte.to_table[:score].gt(5))

        assert_like %{
          WITH "expr1" AS (SELECT * FROM "bar") SELECT * FROM "expr1" WHERE "expr1"."score" > 5
        }, compile(manager.ast)
      end

      test "Nodes::WithRecursive handles table aliases" do
        manager = Table.new(:foo).project(Arel.star).from(Arel.sql("expr1"))
        expr1 = Table.new(:bar).project(Arel.star).as("expr1")
        manager.with(:recursive, expr1)

        assert_like %{
          WITH RECURSIVE expr1 AS (SELECT * FROM "bar") SELECT * FROM expr1
        }, compile(manager.ast)
      end

      test "Nodes::Cte handles CTEs with no MATERIALIZED modifier" do
        cte = Nodes::Cte.new("foo", Table.new(:bar).project(Arel.star))

        assert_like %{
          "foo" AS (SELECT * FROM "bar")
        }, compile(cte)
      end

      test "Nodes::Cte handles CTEs with a MATERIALIZED modifier" do
        cte = Nodes::Cte.new("foo", Table.new(:bar).project(Arel.star), materialized: true)

        assert_like %{
          "foo" AS MATERIALIZED (SELECT * FROM "bar")
        }, compile(cte)
      end

      test "Nodes::Cte handles CTEs with a NOT MATERIALIZED modifier" do
        cte = Nodes::Cte.new("foo", Table.new(:bar).project(Arel.star), materialized: false)

        assert_like %{
          "foo" AS NOT MATERIALIZED (SELECT * FROM "bar")
        }, compile(cte)
      end

      test "Nodes::Fragments joins subexpressions" do
        sql = Arel.sql("SELECT foo, bar") + Arel.sql(" FROM customers")
        assert_like "SELECT foo, bar FROM customers", compile(sql)
      end

      test "Nodes::Fragments can be built by adding SQL fragments one at a time" do
        sql = Arel.sql("SELECT foo, bar")
        sql += Arel.sql("FROM customers")
        sql += Arel.sql("GROUP BY foo")
        assert_like "SELECT foo, bar FROM customers GROUP BY foo", compile(sql)
      end

      private
        def compile(node)
          @visitor.accept(node, Collectors::SQLString.new).value
        end
    end
  end
end
