# frozen_string_literal: true

require_relative "../helper"
require "bigdecimal"

module Arel
  module Visitors
    describe "the to_sql visitor" do
      before do
        @conn = FakeRecord::Base.new
        @visitor = ToSql.new @conn.connection
        @table = Table.new(:users)
        @attr = @table[:id]
      end

      def compile(node)
        @visitor.accept(node, Collectors::SQLString.new).value
      end

      it "works with BindParams" do
        node = Nodes::BindParam.new(1)
        sql = compile node
        _(sql).must_be_like "?"
      end

      it "does not quote BindParams used as part of a ValuesList" do
        bp = Nodes::BindParam.new(1)
        values = Nodes::ValuesList.new([[bp]])
        sql = compile values
        _(sql).must_be_like "VALUES (?)"
      end

      it "can define a dispatch method" do
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

      it "should not quote sql literals" do
        node = @table[Arel.star]
        sql = compile node
        _(sql).must_be_like '"users".*'
      end

      it "should visit named functions" do
        function = Nodes::NamedFunction.new("omg", [Arel.star])
        assert_equal "omg(*)", compile(function)
      end

      it "should chain predications on named functions" do
        function = Nodes::NamedFunction.new("omg", [Arel.star])
        sql = compile(function.eq(2))
        _(sql).must_be_like %{ omg(*) = 2 }
      end

      it "should handle nil with named functions" do
        function = Nodes::NamedFunction.new("omg", [Arel.star])
        sql = compile(function.eq(nil))
        _(sql).must_be_like %{ omg(*) IS NULL }
      end

      it "should visit built-in functions" do
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

      it "should visit built-in functions operating on distinct values" do
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

      it "works with lists" do
        function = Nodes::NamedFunction.new("omg", [Arel.star, Arel.star])
        assert_equal "omg(*, *)", compile(function)
      end

      describe "Nodes::Equality" do
        it "should escape strings" do
          test = Table.new(:users)[:name].eq "Aaron Patterson"
          _(compile(test)).must_be_like %{
            "users"."name" = 'Aaron Patterson'
          }
        end

        it "should handle false" do
          table = Table.new(:users)
          val = Nodes.build_quoted(false, table[:active])
          sql = compile Nodes::Equality.new(val, val)
          _(sql).must_be_like %{ 'f' = 'f' }
        end

        it "should handle nil" do
          sql = compile Nodes::Equality.new(@table[:name], nil)
          _(sql).must_be_like %{ "users"."name" IS NULL }
        end
      end

      describe "Nodes::Grouping" do
        it "wraps nested groupings in brackets only once" do
          sql = compile Nodes::Grouping.new(Nodes::Grouping.new(Nodes.build_quoted("foo")))
          _(sql).must_equal "('foo')"
        end
      end

      describe "Nodes::NotEqual" do
        it "should handle false" do
          val = Nodes.build_quoted(false, @table[:active])
          sql = compile Nodes::NotEqual.new(@table[:active], val)
          _(sql).must_be_like %{ "users"."active" != 'f' }
        end

        it "should handle nil" do
          val = Nodes.build_quoted(nil, @table[:active])
          sql = compile Nodes::NotEqual.new(@table[:name], val)
          _(sql).must_be_like %{ "users"."name" IS NOT NULL }
        end
      end

      describe "Nodes::IsNotDistinctFrom" do
        it "should construct a valid generic SQL statement" do
          test = Table.new(:users)[:name].is_not_distinct_from "Aaron Patterson"
          _(compile(test)).must_be_like %{
            CASE WHEN "users"."name" = 'Aaron Patterson' OR ("users"."name" IS NULL AND 'Aaron Patterson' IS NULL) THEN 0 ELSE 1 END = 0
          }
        end

        it "should handle column names on both sides" do
          test = Table.new(:users)[:first_name].is_not_distinct_from Table.new(:users)[:last_name]
          _(compile(test)).must_be_like %{
            CASE WHEN "users"."first_name" = "users"."last_name" OR ("users"."first_name" IS NULL AND "users"."last_name" IS NULL) THEN 0 ELSE 1 END = 0
          }
        end

        it "should handle nil" do
          val = Nodes.build_quoted(nil, @table[:active])
          sql = compile Nodes::IsNotDistinctFrom.new(@table[:name], val)
          _(sql).must_be_like %{ "users"."name" IS NULL }
        end
      end

      describe "Nodes::IsDistinctFrom" do
        it "should handle column names on both sides" do
          test = Table.new(:users)[:first_name].is_distinct_from Table.new(:users)[:last_name]
          _(compile(test)).must_be_like %{
            CASE WHEN "users"."first_name" = "users"."last_name" OR ("users"."first_name" IS NULL AND "users"."last_name" IS NULL) THEN 0 ELSE 1 END = 1
          }
        end

        it "should handle nil" do
          val = Nodes.build_quoted(nil, @table[:active])
          sql = compile Nodes::IsDistinctFrom.new(@table[:name], val)
          _(sql).must_be_like %{ "users"."name" IS NOT NULL }
        end
      end

      it "should visit string subclass" do
        [
          Class.new(String).new(":'("),
          Class.new(Class.new(String)).new(":'("),
        ].each do |obj|
          val = Nodes.build_quoted(obj, @table[:active])
          sql = compile Nodes::NotEqual.new(@table[:name], val)
          _(sql).must_be_like %{ "users"."name" != ':\\'(' }
        end
      end

      it "should visit_Class" do
        _(compile(Nodes.build_quoted(DateTime))).must_equal "'DateTime'"
      end

      it "should escape LIMIT" do
        sc = Arel::Nodes::SelectStatement.new
        sc.limit = Arel::Nodes::Limit.new(Nodes.build_quoted("omg"))
        assert_match(/LIMIT 'omg'/, compile(sc))
      end

      it "should contain a single space before ORDER BY" do
        table = Table.new(:users)
        test = table.order(table[:name])
        sql = compile test
        assert_match(/"users" ORDER BY/, sql)
      end

      it "should quote LIMIT without column type coercion" do
        table = Table.new(:users)
        sc = table.where(table[:name].eq(0)).take(1).ast
        assert_match(/WHERE "users"."name" = 0 LIMIT 1/, compile(sc))
      end

      it "should visit_DateTime" do
        dt = DateTime.now
        table = Table.new(:users)
        test = table[:created_at].eq dt
        sql = compile test

        _(sql).must_be_like %{"users"."created_at" = '#{dt.strftime("%Y-%m-%d %H:%M:%S")}'}
      end

      it "should visit_Float" do
        test = Table.new(:products)[:price].eq 2.14
        sql = compile test
        _(sql).must_be_like %{"products"."price" = 2.14}
      end

      it "should visit_Not" do
        sql = compile Nodes::Not.new(Arel.sql("foo"))
        _(sql).must_be_like "NOT (foo)"
      end

      it "should apply Not to the whole expression" do
        node = Nodes::And.new [@attr.eq(10), @attr.eq(11)]
        sql = compile Nodes::Not.new(node)
        _(sql).must_be_like %{NOT ("users"."id" = 10 AND "users"."id" = 11)}
      end

      it "should visit_As" do
        as = Nodes::As.new(Arel.sql("foo"), Arel.sql("bar"))
        sql = compile as
        _(sql).must_be_like "foo AS bar"
      end

      it "should visit_Integer" do
        compile 8787878092
      end

      it "should visit_Hash" do
        compile(Nodes.build_quoted(a: 1))
      end

      it "should visit_Set" do
        compile Nodes.build_quoted(Set.new([1, 2]))
      end

      it "should visit_BigDecimal" do
        compile Nodes.build_quoted(BigDecimal("2.14"))
      end

      it "should visit_Date" do
        dt = Date.today
        table = Table.new(:users)
        test = table[:created_at].eq dt
        sql = compile test

        _(sql).must_be_like %{"users"."created_at" = '#{dt.strftime("%Y-%m-%d")}'}
      end

      it "should visit_NilClass" do
        _(compile(Nodes.build_quoted(nil))).must_be_like "NULL"
      end

      it "unsupported input should raise UnsupportedVisitError" do
        error = assert_raises(UnsupportedVisitError) { compile(nil) }
        assert_match(/\AUnsupported/, error.message)
      end

      it "should visit_Arel_SelectManager, which is a subquery" do
        mgr = Table.new(:foo).project(:bar)
        _(compile(mgr)).must_be_like '(SELECT bar FROM "foo")'
      end

      it "should visit_Arel_Nodes_And" do
        node = Nodes::And.new [@attr.eq(10), @attr.eq(11)]
        _(compile(node)).must_be_like %{
          "users"."id" = 10 AND "users"."id" = 11
        }
      end

      it "should visit_Arel_Nodes_Or" do
        node = Nodes::Or.new @attr.eq(10), @attr.eq(11)
        _(compile(node)).must_be_like %{
          "users"."id" = 10 OR "users"."id" = 11
        }
      end

      it "should visit_Arel_Nodes_Assignment" do
        column = @table["id"]
        node = Nodes::Assignment.new(
          Nodes::UnqualifiedColumn.new(column),
          Nodes::UnqualifiedColumn.new(column)
        )
        _(compile(node)).must_be_like %{
          "id" = "id"
        }
      end

      it "should visit_TrueClass" do
        test = Table.new(:users)[:bool].eq(true)
        _(compile(test)).must_be_like %{ "users"."bool" = 't' }
      end

      describe "Nodes::Matches" do
        it "should know how to visit" do
          node = @table[:name].matches("foo%")
          _(compile(node)).must_be_like %{
            "users"."name" LIKE 'foo%'
          }
        end

        it "can handle ESCAPE" do
          node = @table[:name].matches("foo!%", "!")
          _(compile(node)).must_be_like %{
            "users"."name" LIKE 'foo!%' ESCAPE '!'
          }
        end

        it "can handle subqueries" do
          subquery = @table.project(:id).where(@table[:name].matches("foo%"))
          node = @attr.in subquery
          _(compile(node)).must_be_like %{
            "users"."id" IN (SELECT id FROM "users" WHERE "users"."name" LIKE 'foo%')
          }
        end
      end

      describe "Nodes::DoesNotMatch" do
        it "should know how to visit" do
          node = @table[:name].does_not_match("foo%")
          _(compile(node)).must_be_like %{
            "users"."name" NOT LIKE 'foo%'
          }
        end

        it "can handle ESCAPE" do
          node = @table[:name].does_not_match("foo!%", "!")
          _(compile(node)).must_be_like %{
            "users"."name" NOT LIKE 'foo!%' ESCAPE '!'
          }
        end

        it "can handle subqueries" do
          subquery = @table.project(:id).where(@table[:name].does_not_match("foo%"))
          node = @attr.in subquery
          _(compile(node)).must_be_like %{
            "users"."id" IN (SELECT id FROM "users" WHERE "users"."name" NOT LIKE 'foo%')
          }
        end
      end

      describe "Nodes::Ordering" do
        it "should know how to visit" do
          node = @attr.desc
          _(compile(node)).must_be_like %{
            "users"."id" DESC
          }
        end
      end

      describe "Nodes::In" do
        it "should know how to visit" do
          node = @attr.in [1, 2, 3]
          _(compile(node)).must_be_like %{
            "users"."id" IN (1, 2, 3)
          }
        end

        it "should return 1=0 when empty right which is always false" do
          node = @attr.in []
          _(compile(node)).must_equal "1=0"
        end

        it "can handle two dot ranges" do
          node = @attr.between 1..3
          _(compile(node)).must_be_like %{
            "users"."id" BETWEEN 1 AND 3
          }
        end

        it "can handle three dot ranges" do
          node = @attr.between 1...3
          _(compile(node)).must_be_like %{
            "users"."id" >= 1 AND "users"."id" < 3
          }
        end

        it "can handle ranges bounded by infinity" do
          node = @attr.between 1..Float::INFINITY
          _(compile(node)).must_be_like %{
            "users"."id" >= 1
          }
          node = @attr.between(-Float::INFINITY..3)
          _(compile(node)).must_be_like %{
            "users"."id" <= 3
          }
          node = @attr.between(-Float::INFINITY...3)
          _(compile(node)).must_be_like %{
            "users"."id" < 3
          }
          node = @attr.between(-Float::INFINITY..Float::INFINITY)
          _(compile(node)).must_be_like %{1=1}
        end

        it "can handle subqueries" do
          table = Table.new(:users)
          subquery = table.project(:id).where(table[:name].eq("Aaron"))
          node = @attr.in subquery
          _(compile(node)).must_be_like %{
            "users"."id" IN (SELECT id FROM "users" WHERE "users"."name" = 'Aaron')
          }
        end
      end

      describe "Nodes::InfixOperation" do
        it "should handle Multiplication" do
          node = Arel::Attribute.new(Table.new(:products), :price) * Arel::Attribute.new(Table.new(:currency_rates), :rate)
          _(compile(node)).must_equal %("products"."price" * "currency_rates"."rate")
        end

        it "should handle Division" do
          node = Arel::Attribute.new(Table.new(:products), :price) / 5
          _(compile(node)).must_equal %("products"."price" / 5)
        end

        it "should handle Addition" do
          node = Arel::Attribute.new(Table.new(:products), :price) + 6
          _(compile(node)).must_equal %(("products"."price" + 6))
        end

        it "should handle Subtraction" do
          node = Arel::Attribute.new(Table.new(:products), :price) - 7
          _(compile(node)).must_equal %(("products"."price" - 7))
        end

        it "should handle Concatenation" do
          table = Table.new(:users)
          node = table[:name].concat(table[:name])
          _(compile(node)).must_equal %("users"."name" || "users"."name")
        end

        it "should handle Contains" do
          table = Table.new(:users)
          node = table[:name].contains(table[:name])
          _(compile(node)).must_equal %("users"."name" @> "users"."name")
        end

        it "should handle Overlaps" do
          table = Table.new(:users)
          node = table[:name].overlaps(table[:name])
          _(compile(node)).must_equal %("users"."name" && "users"."name")
        end

        it "should handle BitwiseAnd" do
          node = Arel::Attribute.new(Table.new(:products), :bitmap) & 16
          _(compile(node)).must_equal %(("products"."bitmap" & 16))
        end

        it "should handle BitwiseOr" do
          node = Arel::Attribute.new(Table.new(:products), :bitmap) | 16
          _(compile(node)).must_equal %(("products"."bitmap" | 16))
        end

        it "should handle BitwiseXor" do
          node = Arel::Attribute.new(Table.new(:products), :bitmap) ^ 16
          _(compile(node)).must_equal %(("products"."bitmap" ^ 16))
        end

        it "should handle BitwiseShiftLeft" do
          node = Arel::Attribute.new(Table.new(:products), :bitmap) << 4
          _(compile(node)).must_equal %(("products"."bitmap" << 4))
        end

        it "should handle BitwiseShiftRight" do
          node = Arel::Attribute.new(Table.new(:products), :bitmap) >> 4
          _(compile(node)).must_equal %(("products"."bitmap" >> 4))
        end

        it "should handle arbitrary operators" do
          node = Arel::Nodes::InfixOperation.new(
            "&&",
            Arel::Attribute.new(Table.new(:products), :name),
            Arel::Attribute.new(Table.new(:products), :name)
          )
          _(compile(node)).must_equal %("products"."name" && "products"."name")
        end
      end

      describe "Nodes::UnaryOperation" do
        it "should handle BitwiseNot" do
          node = ~ Arel::Attribute.new(Table.new(:products), :bitmap)
          _(compile(node)).must_equal %( ~ "products"."bitmap")
        end

        it "should handle arbitrary operators" do
          node = Arel::Nodes::UnaryOperation.new("!", Arel::Attribute.new(Table.new(:products), :active))
          _(compile(node)).must_equal %( ! "products"."active")
        end
      end

      describe "Nodes::Union" do
        it "squashes parenthesis on multiple unions" do
          subnode = Nodes::Union.new Arel.sql("left"), Arel.sql("right")
          node = Nodes::Union.new subnode, Arel.sql("topright")
          assert_equal("( left UNION right UNION topright )", compile(node))
          subnode = Nodes::Union.new Arel.sql("left"), Arel.sql("right")
          node = Nodes::Union.new Arel.sql("topleft"), subnode
          assert_equal("( topleft UNION left UNION right )", compile(node))
        end
      end

      describe "Nodes::UnionAll" do
        it "squashes parenthesis on multiple union alls" do
          subnode = Nodes::UnionAll.new Arel.sql("left"), Arel.sql("right")
          node = Nodes::UnionAll.new subnode, Arel.sql("topright")
          assert_equal("( left UNION ALL right UNION ALL topright )", compile(node))
          subnode = Nodes::UnionAll.new Arel.sql("left"), Arel.sql("right")
          node = Nodes::UnionAll.new Arel.sql("topleft"), subnode
          assert_equal("( topleft UNION ALL left UNION ALL right )", compile(node))
        end
      end

      describe "Nodes::NotIn" do
        it "should know how to visit" do
          node = @attr.not_in [1, 2, 3]
          _(compile(node)).must_be_like %{
            "users"."id" NOT IN (1, 2, 3)
          }
        end

        it "should return 1=1 when empty right which is always true" do
          node = @attr.not_in []
          _(compile(node)).must_equal "1=1"
        end

        it "can handle two dot ranges" do
          node = @attr.not_between 1..3
          _(compile(node)).must_equal(
            %{("users"."id" < 1 OR "users"."id" > 3)}
          )
        end

        it "can handle three dot ranges" do
          node = @attr.not_between 1...3
          _(compile(node)).must_equal(
            %{("users"."id" < 1 OR "users"."id" >= 3)}
          )
        end

        it "can handle ranges bounded by infinity" do
          node = @attr.not_between 1..Float::INFINITY
          _(compile(node)).must_be_like %{
            "users"."id" < 1
          }
          node = @attr.not_between(-Float::INFINITY..3)
          _(compile(node)).must_be_like %{
            "users"."id" > 3
          }
          node = @attr.not_between(-Float::INFINITY...3)
          _(compile(node)).must_be_like %{
            "users"."id" >= 3
          }
          node = @attr.not_between(-Float::INFINITY..Float::INFINITY)
          _(compile(node)).must_be_like %{1=0}
        end

        it "can handle subqueries" do
          table = Table.new(:users)
          subquery = table.project(:id).where(table[:name].eq("Aaron"))
          node = @attr.not_in subquery
          _(compile(node)).must_be_like %{
            "users"."id" NOT IN (SELECT id FROM "users" WHERE "users"."name" = 'Aaron')
          }
        end
      end

      describe "Constants" do
        it "should handle true" do
          test = Table.new(:users).create_true
          _(compile(test)).must_be_like %{
            TRUE
          }
        end

        it "should handle false" do
          test = Table.new(:users).create_false
          _(compile(test)).must_be_like %{
            FALSE
          }
        end
      end

      describe "TableAlias" do
        it "should use the underlying table for checking columns" do
          test = Table.new(:users).alias("zomgusers")[:id].eq "3"
          _(compile(test)).must_be_like %{
            "zomgusers"."id" = '3'
          }
        end
      end

      describe "distinct on" do
        it "raises not implemented error" do
          core = Arel::Nodes::SelectCore.new
          core.set_quantifier = Arel::Nodes::DistinctOn.new(Arel.sql("aaron"))

          assert_raises(NotImplementedError) do
            compile(core)
          end
        end
      end

      describe "Nodes::Regexp" do
        it "raises not implemented error" do
          node = Arel::Nodes::Regexp.new(@table[:name], Nodes.build_quoted("foo%"))

          assert_raises(NotImplementedError) do
            compile(node)
          end
        end
      end

      describe "Nodes::NotRegexp" do
        it "raises not implemented error" do
          node = Arel::Nodes::NotRegexp.new(@table[:name], Nodes.build_quoted("foo%"))

          assert_raises(NotImplementedError) do
            compile(node)
          end
        end
      end

      describe "Nodes::Case" do
        it "supports simple case expressions" do
          node = Arel::Nodes::Case.new(@table[:name])
            .when("foo").then(1)
            .else(0)

          _(compile(node)).must_be_like %{
            CASE "users"."name" WHEN 'foo' THEN 1 ELSE 0 END
          }
        end

        it "supports extended case expressions" do
          node = Arel::Nodes::Case.new
            .when(@table[:name].in(%w(foo bar))).then(1)
            .else(0)

          _(compile(node)).must_be_like %{
            CASE WHEN "users"."name" IN ('foo', 'bar') THEN 1 ELSE 0 END
          }
        end

        it "works without default branch" do
          node = Arel::Nodes::Case.new(@table[:name])
            .when("foo").then(1)

          _(compile(node)).must_be_like %{
            CASE "users"."name" WHEN 'foo' THEN 1 END
          }
        end

        it "allows chaining multiple conditions" do
          node = Arel::Nodes::Case.new(@table[:name])
            .when("foo").then(1)
            .when("bar").then(2)
            .else(0)

          _(compile(node)).must_be_like %{
            CASE "users"."name" WHEN 'foo' THEN 1 WHEN 'bar' THEN 2 ELSE 0 END
          }
        end

        it "supports #when with two arguments and no #then" do
          node = Arel::Nodes::Case.new @table[:name]

          { foo: 1, bar: 0 }.reduce(node) { |_node, pair| _node.when(*pair) }

          _(compile(node)).must_be_like %{
            CASE "users"."name" WHEN 'foo' THEN 1 WHEN 'bar' THEN 0 END
          }
        end

        it "can be chained as a predicate" do
          node = @table[:name].when("foo").then("bar").else("baz")

          _(compile(node)).must_be_like %{
            CASE "users"."name" WHEN 'foo' THEN 'bar' ELSE 'baz' END
          }
        end
      end

      describe "Nodes::With" do
        it "handles table aliases" do
          manager = Table.new(:foo).project(Arel.star).from(Arel.sql("expr2"))
          expr1 = Table.new(:bar).project(Arel.star).as("expr1")
          expr2 = Table.new(:baz).project(Arel.star).as("expr2")
          manager.with(expr1, expr2)

          _(compile(manager.ast)).must_be_like %{
            WITH expr1 AS (SELECT * FROM "bar"), expr2 AS (SELECT * FROM "baz") SELECT * FROM expr2
          }
        end
      end

      describe "Nodes::WithRecursive" do
        it "handles table aliases" do
          manager = Table.new(:foo).project(Arel.star).from(Arel.sql("expr1"))
          expr1 = Table.new(:bar).project(Arel.star).as("expr1")
          manager.with(:recursive, expr1)

          _(compile(manager.ast)).must_be_like %{
            WITH RECURSIVE expr1 AS (SELECT * FROM "bar") SELECT * FROM expr1
          }
        end
      end
    end
  end
end
