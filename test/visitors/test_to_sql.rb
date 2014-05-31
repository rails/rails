require 'helper'

module Arel
  module Visitors
    describe 'the to_sql visitor' do
      before do
        @conn = FakeRecord::Base.new
        @visitor = ToSql.new @conn.connection
        @table = Table.new(:users)
        @attr = @table[:id]
      end

      def compile node
        @visitor.accept(node, Collectors::SQLString.new).value
      end

      it 'works with BindParams' do
        node = Nodes::BindParam.new 'omg'
        sql = compile node
        sql.must_be_like 'omg'
      end

      it 'can define a dispatch method' do
        visited = false
        viz = Class.new(Arel::Visitors::Reduce) {
          define_method(:hello) do |node, c|
            visited = true
          end

          def dispatch
            { Arel::Table => 'hello' }
          end
        }.new

        viz.accept(@table, Collectors::SQLString.new)
        assert visited, 'hello method was called'
      end

      it 'should not quote sql literals' do
        node = @table[Arel.star]
        sql = compile node
        sql.must_be_like '"users".*'
      end

      it 'should visit named functions' do
        function = Nodes::NamedFunction.new('omg', [Arel.star])
        assert_equal 'omg(*)', compile(function)
      end

      it 'should chain predications on named functions' do
        function = Nodes::NamedFunction.new('omg', [Arel.star])
        sql = compile(function.eq(2))
        sql.must_be_like %{ omg(*) = 2 }
      end

      it 'should visit built-in functions' do
        function = Nodes::Count.new([Arel.star])
        assert_equal 'COUNT(*)', compile(function)

        function = Nodes::Sum.new([Arel.star])
        assert_equal 'SUM(*)', compile(function)

        function = Nodes::Max.new([Arel.star])
        assert_equal 'MAX(*)', compile(function)

        function = Nodes::Min.new([Arel.star])
        assert_equal 'MIN(*)', compile(function)

        function = Nodes::Avg.new([Arel.star])
        assert_equal 'AVG(*)', compile(function)
      end

      it 'should visit built-in functions operating on distinct values' do
        function = Nodes::Count.new([Arel.star])
        function.distinct = true
        assert_equal 'COUNT(DISTINCT *)', compile(function)

        function = Nodes::Sum.new([Arel.star])
        function.distinct = true
        assert_equal 'SUM(DISTINCT *)', compile(function)

        function = Nodes::Max.new([Arel.star])
        function.distinct = true
        assert_equal 'MAX(DISTINCT *)', compile(function)

        function = Nodes::Min.new([Arel.star])
        function.distinct = true
        assert_equal 'MIN(DISTINCT *)', compile(function)

        function = Nodes::Avg.new([Arel.star])
        function.distinct = true
        assert_equal 'AVG(DISTINCT *)', compile(function)
      end

      it 'works with lists' do
        function = Nodes::NamedFunction.new('omg', [Arel.star, Arel.star])
        assert_equal 'omg(*, *)', compile(function)
      end

      describe 'Nodes::Equality' do
        it "should escape strings" do
          test = Table.new(:users)[:name].eq 'Aaron Patterson'
          compile(test).must_be_like %{
            "users"."name" = 'Aaron Patterson'
          }
        end

        it 'should handle false' do
          table = Table.new(:users)
          val = Nodes.build_quoted(false, table[:active])
          sql = compile Nodes::Equality.new(val, val)
          sql.must_be_like %{ 'f' = 'f' }
        end

        it 'should use the column to quote' do
          table = Table.new(:users)
          val = Nodes.build_quoted('1-fooo', table[:id])
          sql = compile Nodes::Equality.new(table[:id], val)
          sql.must_be_like %{ "users"."id" = 1 }
        end

        it 'should use the column to quote integers' do
          table = Table.new(:users)
          sql = compile table[:name].eq(0)
          sql.must_be_like %{ "users"."name" = '0' }
        end

        it 'should handle nil' do
          sql = compile Nodes::Equality.new(@table[:name], nil)
          sql.must_be_like %{ "users"."name" IS NULL }
        end
      end

      describe 'Nodes::NotEqual' do
        it 'should handle false' do
          val = Nodes.build_quoted(false, @table[:active])
          sql = compile Nodes::NotEqual.new(@table[:active], val)
          sql.must_be_like %{ "users"."active" != 'f' }
        end

        it 'should handle nil' do
          val = Nodes.build_quoted(nil, @table[:active])
          sql = compile Nodes::NotEqual.new(@table[:name], val)
          sql.must_be_like %{ "users"."name" IS NOT NULL }
        end
      end

      it "should visit string subclass" do
        [
          Class.new(String).new(":'("),
          Class.new(Class.new(String)).new(":'("),
        ].each do |obj|
          val = Nodes.build_quoted(obj, @table[:active])
          sql = compile Nodes::NotEqual.new(@table[:name], val)
          sql.must_be_like %{ "users"."name" != ':\\'(' }
        end
      end

      it "should visit_Class" do
        compile(Nodes.build_quoted(DateTime)).must_equal "'DateTime'"
      end

      it "should escape LIMIT" do
        sc = Arel::Nodes::SelectStatement.new
        sc.limit = Arel::Nodes::Limit.new(Nodes.build_quoted("omg"))
        assert_match(/LIMIT 'omg'/, compile(sc))
      end

      it "should quote LIMIT without column type coercion" do
        table = Table.new(:users)
        sc = table.where(table[:name].eq(0)).take(1).ast
        assert_match(/WHERE "users"."name" = '0' LIMIT 1/, compile(sc))
      end

      it "should visit_DateTime" do
        called_with = nil
        @conn.connection.extend(Module.new {
          define_method(:quote) do |thing, column|
            called_with = column
            super(thing, column)
          end
        })

        dt = DateTime.now
        table = Table.new(:users)
        test = table[:created_at].eq dt
        sql = compile test

        assert_equal "created_at", called_with.name
        sql.must_be_like %{"users"."created_at" = '#{dt.strftime("%Y-%m-%d %H:%M:%S")}'}
      end

      it "should visit_Float" do
        test = Table.new(:products)[:price].eq 2.14
        sql = compile test
        sql.must_be_like %{"products"."price" = 2.14}
      end

      it "should visit_Not" do
        sql = compile Nodes::Not.new(Arel.sql("foo"))
        sql.must_be_like "NOT (foo)"
      end

      it "should apply Not to the whole expression" do
        node = Nodes::And.new [@attr.eq(10), @attr.eq(11)]
        sql = compile Nodes::Not.new(node)
        sql.must_be_like %{NOT ("users"."id" = 10 AND "users"."id" = 11)}
      end

      it "should visit_As" do
        as = Nodes::As.new(Arel.sql("foo"), Arel.sql("bar"))
        sql = compile as
        sql.must_be_like "foo AS bar"
      end

      it "should visit_Bignum" do
        compile 8787878092
      end

      it "should visit_Hash" do
        compile(Nodes.build_quoted({:a => 1}))
      end

      it "should visit_BigDecimal" do
        compile Nodes.build_quoted(BigDecimal.new('2.14'))
      end

      it "should visit_Date" do
        called_with = nil
        @conn.connection.extend(Module.new {
          define_method(:quote) do |thing, column|
            called_with = column
            super(thing, column)
          end
        })

        dt = Date.today
        table = Table.new(:users)
        test = table[:created_at].eq dt
        sql = compile test

        assert_equal "created_at", called_with.name
        sql.must_be_like %{"users"."created_at" = '#{dt.strftime("%Y-%m-%d")}'}
      end

      it "should visit_NilClass" do
        compile(Nodes.build_quoted(nil)).must_be_like "NULL"
      end

      it "unsupported input should not raise ArgumentError" do
        error = assert_raises(RuntimeError) { compile(nil) }
        assert_match(/\Aunsupported/, error.message)
      end

      it "should visit_Arel_SelectManager, which is a subquery" do
        mgr = Table.new(:foo).project(:bar)
        compile(mgr).must_be_like '(SELECT bar FROM "foo")'
      end

      it "should visit_Arel_Nodes_And" do
        node = Nodes::And.new [@attr.eq(10), @attr.eq(11)]
        compile(node).must_be_like %{
          "users"."id" = 10 AND "users"."id" = 11
        }
      end

      it "should visit_Arel_Nodes_Or" do
        node = Nodes::Or.new @attr.eq(10), @attr.eq(11)
        compile(node).must_be_like %{
          "users"."id" = 10 OR "users"."id" = 11
        }
      end

      it "should visit_Arel_Nodes_Assignment" do
	column = @table["id"] 
	node = Nodes::Assignment.new(
            Nodes::UnqualifiedColumn.new(column),
            Nodes::UnqualifiedColumn.new(column)
          )
        compile(node).must_be_like %{
	  "id" = "id"
	}
      end

      it "should visit visit_Arel_Attributes_Time" do
        attr = Attributes::Time.new(@attr.relation, @attr.name)
        compile attr
      end

      it "should visit_TrueClass" do
        test = Table.new(:users)[:bool].eq(true)
        compile(test).must_be_like %{ "users"."bool" = 't' }
      end

      describe "Nodes::Matches" do
        it "should know how to visit" do
          node = @table[:name].matches('foo%')
          compile(node).must_be_like %{
            "users"."name" LIKE 'foo%'
          }
        end

        it 'can handle subqueries' do
          subquery = @table.project(:id).where(@table[:name].matches('foo%'))
          node = @attr.in subquery
          compile(node).must_be_like %{
            "users"."id" IN (SELECT id FROM "users" WHERE "users"."name" LIKE 'foo%')
          }
        end
      end

      describe "Nodes::DoesNotMatch" do
        it "should know how to visit" do
          node = @table[:name].does_not_match('foo%')
          compile(node).must_be_like %{
            "users"."name" NOT LIKE 'foo%'
          }
        end

        it 'can handle subqueries' do
          subquery = @table.project(:id).where(@table[:name].does_not_match('foo%'))
          node = @attr.in subquery
          compile(node).must_be_like %{
            "users"."id" IN (SELECT id FROM "users" WHERE "users"."name" NOT LIKE 'foo%')
          }
        end
      end

      describe "Nodes::Ordering" do
        it "should know how to visit" do
          node = @attr.desc
          compile(node).must_be_like %{
            "users"."id" DESC
          }
        end
      end

      describe "Nodes::In" do
        it "should know how to visit" do
          node = @attr.in [1, 2, 3]
          compile(node).must_be_like %{
            "users"."id" IN (1, 2, 3)
          }
        end

        it "should return 1=0 when empty right which is always false" do
          node = @attr.in []
          compile(node).must_equal '1=0'
        end

        it 'can handle two dot ranges' do
          node = @attr.in 1..3
          compile(node).must_be_like %{
            "users"."id" BETWEEN 1 AND 3
          }
        end

        it 'can handle three dot ranges' do
          node = @attr.in 1...3
          compile(node).must_be_like %{
            "users"."id" >= 1 AND "users"."id" < 3
          }
        end

        it 'can handle ranges bounded by infinity' do
          node = @attr.in 1..Float::INFINITY
          compile(node).must_be_like %{
            "users"."id" >= 1
          }
          node = @attr.in(-Float::INFINITY..3)
          compile(node).must_be_like %{
            "users"."id" <= 3
          }
          node = @attr.in(-Float::INFINITY...3)
          compile(node).must_be_like %{
            "users"."id" < 3
          }
          node = @attr.in(-Float::INFINITY..Float::INFINITY)
          compile(node).must_be_like %{1=1}
        end

        it 'can handle subqueries' do
          table = Table.new(:users)
          subquery = table.project(:id).where(table[:name].eq('Aaron'))
          node = @attr.in subquery
          compile(node).must_be_like %{
            "users"."id" IN (SELECT id FROM "users" WHERE "users"."name" = 'Aaron')
          }
        end

        it 'uses the same column for escaping values' do
        @attr = Table.new(:users)[:name]
          visitor = Class.new(ToSql) do
            attr_accessor :expected

            def quote value, column = nil
              raise unless column == expected
              super
            end
          end
          vals = %w{ a b c }.map { |x| Nodes.build_quoted(x, @attr) }
          in_node = Nodes::In.new @attr, vals
          visitor = visitor.new(Table.engine.connection)
          visitor.expected = Table.engine.connection.columns(:users).find { |x|
            x.name == 'name'
          }
          visitor.accept(in_node, Collectors::SQLString.new).value.must_equal %("users"."name" IN ('a', 'b', 'c'))
        end
      end

      describe "Nodes::InfixOperation" do
        it "should handle Multiplication" do
          node = Arel::Attributes::Decimal.new(Table.new(:products), :price) * Arel::Attributes::Decimal.new(Table.new(:currency_rates), :rate)
          compile(node).must_equal %("products"."price" * "currency_rates"."rate")
        end

        it "should handle Division" do
          node = Arel::Attributes::Decimal.new(Table.new(:products), :price) / 5
          compile(node).must_equal %("products"."price" / 5)
        end

        it "should handle Addition" do
          node = Arel::Attributes::Decimal.new(Table.new(:products), :price) + 6
          compile(node).must_equal %(("products"."price" + 6))
        end

        it "should handle Subtraction" do
          node = Arel::Attributes::Decimal.new(Table.new(:products), :price) - 7
          compile(node).must_equal %(("products"."price" - 7))
        end

        it "should handle arbitrary operators" do
          node = Arel::Nodes::InfixOperation.new(
            '||',
            Arel::Attributes::String.new(Table.new(:products), :name),
            Arel::Attributes::String.new(Table.new(:products), :name)
          )
          compile(node).must_equal %("products"."name" || "products"."name")
        end
      end

      describe "Nodes::NotIn" do
        it "should know how to visit" do
          node = @attr.not_in [1, 2, 3]
          compile(node).must_be_like %{
            "users"."id" NOT IN (1, 2, 3)
          }
        end

        it "should return 1=1 when empty right which is always true" do
          node = @attr.not_in []
          compile(node).must_equal '1=1'
        end

        it 'can handle two dot ranges' do
          node = @attr.not_in 1..3
          compile(node).must_be_like %{
            "users"."id" < 1 OR "users"."id" > 3
          }
        end

        it 'can handle three dot ranges' do
          node = @attr.not_in 1...3
          compile(node).must_be_like %{
            "users"."id" < 1 OR "users"."id" >= 3
          }
        end

        it 'can handle ranges bounded by infinity' do
          node = @attr.not_in 1..Float::INFINITY
          compile(node).must_be_like %{
            "users"."id" < 1
          }
          node = @attr.not_in(-Float::INFINITY..3)
          compile(node).must_be_like %{
            "users"."id" > 3
          }
          node = @attr.not_in(-Float::INFINITY...3)
          compile(node).must_be_like %{
            "users"."id" >= 3
          }
          node = @attr.not_in(-Float::INFINITY..Float::INFINITY)
          compile(node).must_be_like %{1=0}
        end

        it 'can handle subqueries' do
          table = Table.new(:users)
          subquery = table.project(:id).where(table[:name].eq('Aaron'))
          node = @attr.not_in subquery
          compile(node).must_be_like %{
            "users"."id" NOT IN (SELECT id FROM "users" WHERE "users"."name" = 'Aaron')
          }
        end

        it 'uses the same column for escaping values' do
        @attr = Table.new(:users)[:name]
          visitor = Class.new(ToSql) do
            attr_accessor :expected

            def quote value, column = nil
              raise unless column == expected
              super
            end
          end
          vals = %w{ a b c }.map { |x| Nodes.build_quoted(x, @attr) }
          in_node = Nodes::NotIn.new @attr, vals
          visitor = visitor.new(Table.engine.connection)
          visitor.expected = Table.engine.connection.columns(:users).find { |x|
            x.name == 'name'
          }
          compile(in_node).must_equal %("users"."name" NOT IN ('a', 'b', 'c'))
        end
      end

      describe 'Constants' do
        it "should handle true" do
          test = Table.new(:users).create_true
          compile(test).must_be_like %{
            TRUE
          }
        end

        it "should handle false" do
          test = Table.new(:users).create_false
          compile(test).must_be_like %{
            FALSE
          }
        end
      end

      describe 'TableAlias' do
        it "should use the underlying table for checking columns" do
          test = Table.new(:users).alias('zomgusers')[:id].eq '3'
          compile(test).must_be_like %{
            "zomgusers"."id" = 3
          }
        end
      end

      describe 'distinct on' do
        it 'raises not implemented error' do
          core = Arel::Nodes::SelectCore.new
          core.set_quantifier = Arel::Nodes::DistinctOn.new(Arel.sql('aaron'))

          assert_raises(NotImplementedError) do
            compile(core)
          end
        end
      end

      describe 'Nodes::Regexp' do
        it 'raises not implemented error' do
          node = Arel::Nodes::Regexp.new(@table[:name], Nodes.build_quoted('foo%'))

          assert_raises(NotImplementedError) do
            compile(node)
          end
        end
      end

      describe 'Nodes::NotRegexp' do
        it 'raises not implemented error' do
          node = Arel::Nodes::NotRegexp.new(@table[:name], Nodes.build_quoted('foo%'))

          assert_raises(NotImplementedError) do
            compile(node)
          end
        end
      end
    end
  end
end
