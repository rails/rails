# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Visitors
    class PostgresTest < Arel::Test
      setup do
        @visitor = PostgreSQL.new Table.engine.lease_connection
        @table = Table.new(:users)
        @attr = @table[:id]
      end

      test "locking defaults to FOR UPDATE" do
        assert_like %{
          FOR UPDATE
        }, compile(Nodes::Lock.new(Arel.sql("FOR UPDATE")))
      end

      test "locking allows a custom string to be used as a lock" do
        node = Nodes::Lock.new(Arel.sql("FOR SHARE"))
        assert_like %{
          FOR SHARE
        }, compile(node)
      end

      test "should escape LIMIT" do
        sc = Arel::Nodes::SelectStatement.new
        sc.limit = Nodes::Limit.new(Nodes.build_quoted("omg"))
        sc.cores.first.projections << Arel.sql("DISTINCT ON")
        sc.orders << Arel.sql("xyz")
        sql = compile(sc)
        assert_match(/LIMIT 'omg'/, sql)
        assert_equal 1, sql.scan(/LIMIT/).length, "should have one limit"
      end

      test "should support DISTINCT ON" do
        core = Arel::Nodes::SelectCore.new
        core.set_quantifier = Arel::Nodes::DistinctOn.new(Arel.sql("aaron"))
        assert_match "DISTINCT ON ( aaron )", compile(core)
      end

      test "should support DISTINCT" do
        core = Arel::Nodes::SelectCore.new
        core.set_quantifier = Arel::Nodes::Distinct.new
        assert_equal "SELECT DISTINCT", compile(core)
      end

      test "encloses LATERAL queries in parens" do
        subquery = @table.project(:id).where(@table[:name].matches("foo%"))
        assert_like %{
          LATERAL (SELECT id FROM "users" WHERE "users"."name" ILIKE 'foo%')
        }, compile(subquery.lateral)
      end

      test "produces LATERAL queries with alias" do
        subquery = @table.project(:id).where(@table[:name].matches("foo%"))
        assert_like %{
          LATERAL (SELECT id FROM "users" WHERE "users"."name" ILIKE 'foo%') bar
        }, compile(subquery.lateral("bar"))
      end

      test "Nodes::Matches should know how to visit" do
        node = @table[:name].matches("foo%")
        assert_kind_of Nodes::Matches, node
        assert_equal false, node.case_sensitive
        assert_like %{
          "users"."name" ILIKE 'foo%'
        }, compile(node)
      end

      test "Nodes::Matches should know how to visit case sensitive" do
        node = @table[:name].matches("foo%", nil, true)
        assert_equal true, node.case_sensitive
        assert_like %{
          "users"."name" LIKE 'foo%'
        }, compile(node)
      end

      test "Nodes::Matches can handle ESCAPE" do
        node = @table[:name].matches("foo!%", "!")
        assert_like %{
          "users"."name" ILIKE 'foo!%' ESCAPE '!'
        }, compile(node)
      end

      test "Nodes::Matches can handle subqueries" do
        subquery = @table.project(:id).where(@table[:name].matches("foo%"))
        node = @attr.in subquery
        assert_like %{
          "users"."id" IN (SELECT id FROM "users" WHERE "users"."name" ILIKE 'foo%')
        }, compile(node)
      end

      test "Nodes::DoesNotMatch should know how to visit" do
        node = @table[:name].does_not_match("foo%")
        assert_kind_of Nodes::DoesNotMatch, node
        assert_equal false, node.case_sensitive
        assert_like %{
          "users"."name" NOT ILIKE 'foo%'
        }, compile(node)
      end

      test "Nodes::DoesNotMatch should know how to visit case sensitive" do
        node = @table[:name].does_not_match("foo%", nil, true)
        assert_equal true, node.case_sensitive
        assert_like %{
          "users"."name" NOT LIKE 'foo%'
        }, compile(node)
      end

      test "Nodes::DoesNotMatch can handle ESCAPE" do
        node = @table[:name].does_not_match("foo!%", "!")
        assert_like %{
          "users"."name" NOT ILIKE 'foo!%' ESCAPE '!'
        }, compile(node)
      end

      test "Nodes::DoesNotMatch can handle subqueries" do
        subquery = @table.project(:id).where(@table[:name].does_not_match("foo%"))
        node = @attr.in subquery
        assert_like %{
          "users"."id" IN (SELECT id FROM "users" WHERE "users"."name" NOT ILIKE 'foo%')
        }, compile(node)
      end

      test "Nodes::Regexp should know how to visit" do
        node = @table[:name].matches_regexp("foo.*")
        assert_kind_of Nodes::Regexp, node
        assert_equal true, node.case_sensitive
        assert_like %{
          "users"."name" ~ 'foo.*'
        }, compile(node)
      end

      test "Nodes::Regexp can handle case insensitive" do
        node = @table[:name].matches_regexp("foo.*", false)
        assert_kind_of Nodes::Regexp, node
        assert_equal false, node.case_sensitive
        assert_like %{
          "users"."name" ~* 'foo.*'
        }, compile(node)
      end

      test "Nodes::Regexp can handle subqueries" do
        subquery = @table.project(:id).where(@table[:name].matches_regexp("foo.*"))
        node = @attr.in subquery
        assert_like %{
          "users"."id" IN (SELECT id FROM "users" WHERE "users"."name" ~ 'foo.*')
        }, compile(node)
      end

      test "Nodes::NotRegexp should know how to visit" do
        node = @table[:name].does_not_match_regexp("foo.*")
        assert_kind_of Nodes::NotRegexp, node
        assert_equal true, node.case_sensitive
        assert_like %{
          "users"."name" !~ 'foo.*'
        }, compile(node)
      end

      test "Nodes::NotRegexp can handle case insensitive" do
        node = @table[:name].does_not_match_regexp("foo.*", false)
        assert_equal false, node.case_sensitive
        assert_like %{
          "users"."name" !~* 'foo.*'
        }, compile(node)
      end

      test "Nodes::NotRegexp can handle subqueries" do
        subquery = @table.project(:id).where(@table[:name].does_not_match_regexp("foo.*"))
        node = @attr.in subquery
        assert_like %{
          "users"."id" IN (SELECT id FROM "users" WHERE "users"."name" !~ 'foo.*')
        }, compile(node)
      end

      test "Nodes::BindParam increments each bind param" do
        query = @table[:name].eq(Arel::Nodes::BindParam.new(1))
          .and(@table[:id].eq(Arel::Nodes::BindParam.new(1)))
        assert_like %{
          "users"."name" = $1 AND "users"."id" = $2
        }, compile(query)
      end

      test "insert statements render RETURNING" do
        manager = InsertManager.new
        manager.into @table
        manager.insert [[@table[:name], "hello"]]
        manager.returning @table[:id]

        assert_like %{
          INSERT INTO "users" ("name") VALUES ('hello') RETURNING "users"."id"
        }, compile(manager.ast)
      end

      test "delete statements render RETURNING" do
        manager = DeleteManager.new
        manager.from @table
        manager.where @table[:name].eq("hello")
        manager.returning @table[:id]

        assert_like %{
          DELETE FROM "users" WHERE "users"."name" = 'hello' RETURNING "users"."id"
        }, compile(manager.ast)
      end

      test "update statements render RETURNING" do
        manager = UpdateManager.new
        manager.table @table
        manager.set [[@table[:name], "hello"]]
        manager.returning @table[:id]

        assert_like %{
          UPDATE "users" SET "name" = 'hello' RETURNING "users"."id"
        }, compile(manager.ast)
      end

      test "update statements with joins render RETURNING" do
        posts = Table.new(:posts)
        join_source = Arel::Nodes::JoinSource.new(
          @table,
          [@table.create_join(posts)]
        )

        manager = UpdateManager.new
        manager.table join_source
        manager.set [[@table[:name], "hello"]]
        manager.returning @table[:id]

        assert_like %{
          UPDATE "users" SET "name" = 'hello' FROM CROSS JOIN "posts" RETURNING "users"."id"
        }, compile(manager.ast)
      end

      test "Nodes::Cube should know how to visit with array arguments" do
        node = Arel::Nodes::Cube.new([@table[:name], @table[:bool]])
        assert_like %{
          CUBE( "users"."name", "users"."bool" )
        }, compile(node)
      end

      test "Nodes::Cube should know how to visit with CubeDimension Argument" do
        dimensions = Arel::Nodes::GroupingElement.new([@table[:name], @table[:bool]])
        node = Arel::Nodes::Cube.new(dimensions)
        assert_like %{
          CUBE( "users"."name", "users"."bool" )
        }, compile(node)
      end

      test "Nodes::Cube should know how to generate parenthesis when supplied with many Dimensions" do
        dim1 = Arel::Nodes::GroupingElement.new(@table[:name])
        dim2 = Arel::Nodes::GroupingElement.new([@table[:bool], @table[:created_at]])
        node = Arel::Nodes::Cube.new([dim1, dim2])
        assert_like %{
          CUBE( ( "users"."name" ), ( "users"."bool", "users"."created_at" ) )
        }, compile(node)
      end

      test "Nodes::GroupingSet should know how to visit with array arguments" do
        node = Arel::Nodes::GroupingSet.new([@table[:name], @table[:bool]])
        assert_like %{
          GROUPING SETS( "users"."name", "users"."bool" )
        }, compile(node)
      end

      test "Nodes::GroupingSet should know how to visit with CubeDimension Argument" do
        group = Arel::Nodes::GroupingElement.new([@table[:name], @table[:bool]])
        node = Arel::Nodes::GroupingSet.new(group)
        assert_like %{
          GROUPING SETS( "users"."name", "users"."bool" )
        }, compile(node)
      end

      test "Nodes::GroupingSet should know how to generate parenthesis when supplied with many Dimensions" do
        group1 = Arel::Nodes::GroupingElement.new(@table[:name])
        group2 = Arel::Nodes::GroupingElement.new([@table[:bool], @table[:created_at]])
        node = Arel::Nodes::GroupingSet.new([group1, group2])
        assert_like %{
          GROUPING SETS( ( "users"."name" ), ( "users"."bool", "users"."created_at" ) )
        }, compile(node)
      end

      test "Nodes::RollUp should know how to visit with array arguments" do
        node = Arel::Nodes::RollUp.new([@table[:name], @table[:bool]])
        assert_like %{
          ROLLUP( "users"."name", "users"."bool" )
        }, compile(node)
      end

      test "Nodes::RollUp should know how to visit with CubeDimension Argument" do
        group = Arel::Nodes::GroupingElement.new([@table[:name], @table[:bool]])
        node = Arel::Nodes::RollUp.new(group)
        assert_like %{
          ROLLUP( "users"."name", "users"."bool" )
        }, compile(node)
      end

      test "Nodes::RollUp should know how to generate parenthesis when supplied with many Dimensions" do
        group1 = Arel::Nodes::GroupingElement.new(@table[:name])
        group2 = Arel::Nodes::GroupingElement.new([@table[:bool], @table[:created_at]])
        node = Arel::Nodes::RollUp.new([group1, group2])
        assert_like %{
          ROLLUP( ( "users"."name" ), ( "users"."bool", "users"."created_at" ) )
        }, compile(node)
      end

      test "Nodes::IsNotDistinctFrom should construct a valid generic SQL statement" do
        node = Table.new(:users)[:name].is_not_distinct_from "Aaron Patterson"
        assert_like %{
          "users"."name" IS NOT DISTINCT FROM 'Aaron Patterson'
        }, compile(node)
      end

      test "Nodes::IsNotDistinctFrom should handle column names on both sides" do
        node = Table.new(:users)[:first_name].is_not_distinct_from Table.new(:users)[:last_name]
        assert_like %{
          "users"."first_name" IS NOT DISTINCT FROM "users"."last_name"
        }, compile(node)
      end

      test "Nodes::IsNotDistinctFrom should handle nil" do
        table = Table.new(:users)
        value = Nodes.build_quoted(nil, table[:active])
        sql = compile Nodes::IsNotDistinctFrom.new(table[:name], value)
        assert_like %{ "users"."name" IS NOT DISTINCT FROM NULL }, sql
      end

      test "Nodes::IsDistinctFrom should handle column names on both sides" do
        node = Table.new(:users)[:first_name].is_distinct_from Table.new(:users)[:last_name]
        assert_like %{
          "users"."first_name" IS DISTINCT FROM "users"."last_name"
        }, compile(node)
      end

      test "Nodes::IsDistinctFrom should handle nil" do
        table = Table.new(:users)
        value = Nodes.build_quoted(nil, table[:active])
        sql = compile Nodes::IsDistinctFrom.new(table[:name], value)
        assert_like %{ "users"."name" IS DISTINCT FROM NULL }, sql
      end

      test "Nodes::InfixOperation should handle Contains" do
        inner = Nodes.build_quoted('{"foo":"bar"}')
        outer = Table.new(:products)[:metadata]
        sql = compile Nodes::Contains.new(outer, inner)
        assert_like %{ "products"."metadata" @> '{"foo":"bar"}' }, sql
      end

      test "Nodes::InfixOperation should handle Overlaps" do
        column = Table.new(:products)[:tags]
        search = Nodes.build_quoted("{foo,bar,baz}")
        sql = compile Nodes::Overlaps.new(column, search)
        assert_like %{ "products"."tags" && '{foo,bar,baz}' }, sql
      end

      private
        def compile(node)
          @visitor.accept(node, Collectors::SQLString.new).value
        end
    end
  end
end
