# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Visitors
    class PostgresTest < Arel::Spec
      before do
        @visitor = PostgreSQL.new Table.engine.connection
        @table = Table.new(:users)
        @attr = @table[:id]
      end

      def compile(node)
        @visitor.accept(node, Collectors::SQLString.new).value
      end

      describe "locking" do
        it "defaults to FOR UPDATE" do
          _(compile(Nodes::Lock.new(Arel.sql("FOR UPDATE")))).must_be_like %{
            FOR UPDATE
          }
        end

        it "allows a custom string to be used as a lock" do
          node = Nodes::Lock.new(Arel.sql("FOR SHARE"))
          _(compile(node)).must_be_like %{
            FOR SHARE
          }
        end
      end

      it "should escape LIMIT" do
        sc = Arel::Nodes::SelectStatement.new
        sc.limit = Nodes::Limit.new(Nodes.build_quoted("omg"))
        sc.cores.first.projections << Arel.sql("DISTINCT ON")
        sc.orders << Arel.sql("xyz")
        sql = compile(sc)
        assert_match(/LIMIT 'omg'/, sql)
        assert_equal 1, sql.scan(/LIMIT/).length, "should have one limit"
      end

      it "should support DISTINCT ON" do
        core = Arel::Nodes::SelectCore.new
        core.set_quantifier = Arel::Nodes::DistinctOn.new(Arel.sql("aaron"))
        assert_match "DISTINCT ON ( aaron )", compile(core)
      end

      it "should support DISTINCT" do
        core = Arel::Nodes::SelectCore.new
        core.set_quantifier = Arel::Nodes::Distinct.new
        assert_equal "SELECT DISTINCT", compile(core)
      end

      it "encloses LATERAL queries in parens" do
        subquery = @table.project(:id).where(@table[:name].matches("foo%"))
        _(compile(subquery.lateral)).must_be_like %{
          LATERAL (SELECT id FROM "users" WHERE "users"."name" ILIKE 'foo%')
        }
      end

      it "produces LATERAL queries with alias" do
        subquery = @table.project(:id).where(@table[:name].matches("foo%"))
        _(compile(subquery.lateral("bar"))).must_be_like %{
          LATERAL (SELECT id FROM "users" WHERE "users"."name" ILIKE 'foo%') bar
        }
      end

      describe "Nodes::Matches" do
        it "should know how to visit" do
          node = @table[:name].matches("foo%")
          _(node).must_be_kind_of Nodes::Matches
          _(node.case_sensitive).must_equal(false)
          _(compile(node)).must_be_like %{
            "users"."name" ILIKE 'foo%'
          }
        end

        it "should know how to visit case sensitive" do
          node = @table[:name].matches("foo%", nil, true)
          _(node.case_sensitive).must_equal(true)
          _(compile(node)).must_be_like %{
            "users"."name" LIKE 'foo%'
          }
        end

        it "can handle ESCAPE" do
          node = @table[:name].matches("foo!%", "!")
          _(compile(node)).must_be_like %{
            "users"."name" ILIKE 'foo!%' ESCAPE '!'
          }
        end

        it "can handle subqueries" do
          subquery = @table.project(:id).where(@table[:name].matches("foo%"))
          node = @attr.in subquery
          _(compile(node)).must_be_like %{
            "users"."id" IN (SELECT id FROM "users" WHERE "users"."name" ILIKE 'foo%')
          }
        end
      end

      describe "Nodes::DoesNotMatch" do
        it "should know how to visit" do
          node = @table[:name].does_not_match("foo%")
          _(node).must_be_kind_of Nodes::DoesNotMatch
          _(node.case_sensitive).must_equal(false)
          _(compile(node)).must_be_like %{
            "users"."name" NOT ILIKE 'foo%'
          }
        end

        it "should know how to visit case sensitive" do
          node = @table[:name].does_not_match("foo%", nil, true)
          _(node.case_sensitive).must_equal(true)
          _(compile(node)).must_be_like %{
            "users"."name" NOT LIKE 'foo%'
          }
        end

        it "can handle ESCAPE" do
          node = @table[:name].does_not_match("foo!%", "!")
          _(compile(node)).must_be_like %{
            "users"."name" NOT ILIKE 'foo!%' ESCAPE '!'
          }
        end

        it "can handle subqueries" do
          subquery = @table.project(:id).where(@table[:name].does_not_match("foo%"))
          node = @attr.in subquery
          _(compile(node)).must_be_like %{
            "users"."id" IN (SELECT id FROM "users" WHERE "users"."name" NOT ILIKE 'foo%')
          }
        end
      end

      describe "Nodes::Regexp" do
        it "should know how to visit" do
          node = @table[:name].matches_regexp("foo.*")
          _(node).must_be_kind_of Nodes::Regexp
          _(node.case_sensitive).must_equal(true)
          _(compile(node)).must_be_like %{
            "users"."name" ~ 'foo.*'
          }
        end

        it "can handle case insensitive" do
          node = @table[:name].matches_regexp("foo.*", false)
          _(node).must_be_kind_of Nodes::Regexp
          _(node.case_sensitive).must_equal(false)
          _(compile(node)).must_be_like %{
            "users"."name" ~* 'foo.*'
          }
        end

        it "can handle subqueries" do
          subquery = @table.project(:id).where(@table[:name].matches_regexp("foo.*"))
          node = @attr.in subquery
          _(compile(node)).must_be_like %{
            "users"."id" IN (SELECT id FROM "users" WHERE "users"."name" ~ 'foo.*')
          }
        end
      end

      describe "Nodes::NotRegexp" do
        it "should know how to visit" do
          node = @table[:name].does_not_match_regexp("foo.*")
          _(node).must_be_kind_of Nodes::NotRegexp
          _(node.case_sensitive).must_equal(true)
          _(compile(node)).must_be_like %{
            "users"."name" !~ 'foo.*'
          }
        end

        it "can handle case insensitive" do
          node = @table[:name].does_not_match_regexp("foo.*", false)
          _(node.case_sensitive).must_equal(false)
          _(compile(node)).must_be_like %{
            "users"."name" !~* 'foo.*'
          }
        end

        it "can handle subqueries" do
          subquery = @table.project(:id).where(@table[:name].does_not_match_regexp("foo.*"))
          node = @attr.in subquery
          _(compile(node)).must_be_like %{
            "users"."id" IN (SELECT id FROM "users" WHERE "users"."name" !~ 'foo.*')
          }
        end
      end

      describe "Nodes::BindParam" do
        it "increments each bind param" do
          query = @table[:name].eq(Arel::Nodes::BindParam.new(1))
            .and(@table[:id].eq(Arel::Nodes::BindParam.new(1)))
          _(compile(query)).must_be_like %{
            "users"."name" = $1 AND "users"."id" = $2
          }
        end
      end

      describe "Nodes::Cube" do
        it "should know how to visit with array arguments" do
          node = Arel::Nodes::Cube.new([@table[:name], @table[:bool]])
          _(compile(node)).must_be_like %{
            CUBE( "users"."name", "users"."bool" )
          }
        end

        it "should know how to visit with CubeDimension Argument" do
          dimensions = Arel::Nodes::GroupingElement.new([@table[:name], @table[:bool]])
          node = Arel::Nodes::Cube.new(dimensions)
          _(compile(node)).must_be_like %{
            CUBE( "users"."name", "users"."bool" )
          }
        end

        it "should know how to generate parenthesis when supplied with many Dimensions" do
          dim1 = Arel::Nodes::GroupingElement.new(@table[:name])
          dim2 = Arel::Nodes::GroupingElement.new([@table[:bool], @table[:created_at]])
          node = Arel::Nodes::Cube.new([dim1, dim2])
          _(compile(node)).must_be_like %{
            CUBE( ( "users"."name" ), ( "users"."bool", "users"."created_at" ) )
          }
        end
      end

      describe "Nodes::GroupingSet" do
        it "should know how to visit with array arguments" do
          node = Arel::Nodes::GroupingSet.new([@table[:name], @table[:bool]])
          _(compile(node)).must_be_like %{
            GROUPING SETS( "users"."name", "users"."bool" )
          }
        end

        it "should know how to visit with CubeDimension Argument" do
          group = Arel::Nodes::GroupingElement.new([@table[:name], @table[:bool]])
          node = Arel::Nodes::GroupingSet.new(group)
          _(compile(node)).must_be_like %{
            GROUPING SETS( "users"."name", "users"."bool" )
          }
        end

        it "should know how to generate parenthesis when supplied with many Dimensions" do
          group1 = Arel::Nodes::GroupingElement.new(@table[:name])
          group2 = Arel::Nodes::GroupingElement.new([@table[:bool], @table[:created_at]])
          node = Arel::Nodes::GroupingSet.new([group1, group2])
          _(compile(node)).must_be_like %{
            GROUPING SETS( ( "users"."name" ), ( "users"."bool", "users"."created_at" ) )
          }
        end
      end

      describe "Nodes::RollUp" do
        it "should know how to visit with array arguments" do
          node = Arel::Nodes::RollUp.new([@table[:name], @table[:bool]])
          _(compile(node)).must_be_like %{
            ROLLUP( "users"."name", "users"."bool" )
          }
        end

        it "should know how to visit with CubeDimension Argument" do
          group = Arel::Nodes::GroupingElement.new([@table[:name], @table[:bool]])
          node = Arel::Nodes::RollUp.new(group)
          _(compile(node)).must_be_like %{
            ROLLUP( "users"."name", "users"."bool" )
          }
        end

        it "should know how to generate parenthesis when supplied with many Dimensions" do
          group1 = Arel::Nodes::GroupingElement.new(@table[:name])
          group2 = Arel::Nodes::GroupingElement.new([@table[:bool], @table[:created_at]])
          node = Arel::Nodes::RollUp.new([group1, group2])
          _(compile(node)).must_be_like %{
            ROLLUP( ( "users"."name" ), ( "users"."bool", "users"."created_at" ) )
          }
        end
      end

      describe "Nodes::IsNotDistinctFrom" do
        it "should construct a valid generic SQL statement" do
          test = Table.new(:users)[:name].is_not_distinct_from "Aaron Patterson"
          _(compile(test)).must_be_like %{
            "users"."name" IS NOT DISTINCT FROM 'Aaron Patterson'
          }
        end

        it "should handle column names on both sides" do
          test = Table.new(:users)[:first_name].is_not_distinct_from Table.new(:users)[:last_name]
          _(compile(test)).must_be_like %{
            "users"."first_name" IS NOT DISTINCT FROM "users"."last_name"
          }
        end

        it "should handle nil" do
          @table = Table.new(:users)
          val = Nodes.build_quoted(nil, @table[:active])
          sql = compile Nodes::IsNotDistinctFrom.new(@table[:name], val)
          _(sql).must_be_like %{ "users"."name" IS NOT DISTINCT FROM NULL }
        end
      end

      describe "Nodes::IsDistinctFrom" do
        it "should handle column names on both sides" do
          test = Table.new(:users)[:first_name].is_distinct_from Table.new(:users)[:last_name]
          _(compile(test)).must_be_like %{
            "users"."first_name" IS DISTINCT FROM "users"."last_name"
          }
        end

        it "should handle nil" do
          @table = Table.new(:users)
          val = Nodes.build_quoted(nil, @table[:active])
          sql = compile Nodes::IsDistinctFrom.new(@table[:name], val)
          _(sql).must_be_like %{ "users"."name" IS DISTINCT FROM NULL }
        end
      end

      describe "Nodes::Ordering" do
        it "should handle nulls first" do
          test = Table.new(:users)[:first_name].desc.nulls_first
          _(compile(test)).must_be_like %{
            "users"."first_name" DESC NULLS FIRST
          }
        end

        it "should handle nulls last" do
          test = Table.new(:users)[:first_name].desc.nulls_last
          _(compile(test)).must_be_like %{
            "users"."first_name" DESC NULLS LAST
          }
        end

        it "should handle nulls first reversed" do
          test = Table.new(:users)[:first_name].desc.nulls_first.reverse
          _(compile(test)).must_be_like %{
            "users"."first_name" ASC NULLS LAST
          }
        end

        it "should handle nulls last reversed" do
          test = Table.new(:users)[:first_name].desc.nulls_last.reverse
          _(compile(test)).must_be_like %{
            "users"."first_name" ASC NULLS FIRST
          }
        end
      end

      describe "Nodes::InfixOperation" do
        it "should handle Contains" do
          inner = Nodes.build_quoted('{"foo":"bar"}')
          outer = Table.new(:products)[:metadata]
          sql = compile Nodes::Contains.new(outer, inner)
          _(sql).must_be_like %{ "products"."metadata" @> '{"foo":"bar"}' }
        end

        it "should handle Overlaps" do
          column = Table.new(:products)[:tags]
          search = Nodes.build_quoted("{foo,bar,baz}")
          sql = compile Nodes::Overlaps.new(column, search)
          _(sql).must_be_like %{ "products"."tags" && '{foo,bar,baz}' }
        end
      end
    end
  end
end
