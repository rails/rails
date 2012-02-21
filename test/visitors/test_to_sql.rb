require 'helper'

module Arel
  module Visitors
    describe 'the to_sql visitor' do
      before do
        @visitor = ToSql.new Table.engine.connection
        @table = Table.new(:users)
        @attr = @table[:id]
      end

      it 'works with BindParams' do
        node = Nodes::BindParam.new 'omg'
        sql = @visitor.accept node
        sql.must_be_like 'omg'
      end

      it 'can define a dispatch method' do
        visited = false
        viz = Class.new(Arel::Visitors::Visitor) {
          define_method(:hello) do |node|
            visited = true
          end

          def dispatch
            { Arel::Table => 'hello' }
          end
        }.new

        viz.accept(@table)
        assert visited, 'hello method was called'
      end

      it 'should not quote sql literals' do
        node = @table[Arel.star]
        sql = @visitor.accept node
        sql.must_be_like '"users".*'
      end

      it 'should visit named functions' do
        function = Nodes::NamedFunction.new('omg', [Arel.star])
        assert_equal 'omg(*)', @visitor.accept(function)
      end

      it 'should chain predications on named functions' do
        function = Nodes::NamedFunction.new('omg', [Arel.star])
        sql = @visitor.accept(function.eq(2))
        sql.must_be_like %{ omg(*) = 2 }
      end

      it 'works with lists' do
        function = Nodes::NamedFunction.new('omg', [Arel.star, Arel.star])
        assert_equal 'omg(*, *)', @visitor.accept(function)
      end

      describe 'equality' do
        it 'should handle false' do
          sql = @visitor.accept Nodes::Equality.new(false, false)
          sql.must_be_like %{ 'f' = 'f' }
        end

        it 'should use the column to quote' do
          table = Table.new(:users)
          sql = @visitor.accept Nodes::Equality.new(table[:id], '1-fooo')
          sql.must_be_like %{ "users"."id" = 1 }
        end
      end

      it "should visit string subclass" do
        @visitor.accept(Class.new(String).new(":'("))
        @visitor.accept(Class.new(Class.new(String)).new(":'("))
      end

      it "should visit_Class" do
        @visitor.accept(DateTime).must_equal "'DateTime'"
      end

      it "should escape LIMIT" do
        sc = Arel::Nodes::SelectStatement.new
        sc.limit = Arel::Nodes::Limit.new("omg")
        assert_match(/LIMIT 'omg'/, @visitor.accept(sc))
      end

      it "should visit_DateTime" do
        @visitor.accept DateTime.now
      end

      it "should visit_Float" do
        @visitor.accept 2.14
      end

      it "should visit_Not" do
        sql = @visitor.accept Nodes::Not.new(Arel.sql("foo"))
        sql.must_be_like "NOT (foo)"
      end

      it "should apply Not to the whole expression" do
        node = Nodes::And.new [@attr.eq(10), @attr.eq(11)]
        sql = @visitor.accept Nodes::Not.new(node)
        sql.must_be_like %{NOT ("users"."id" = 10 AND "users"."id" = 11)}
      end

      it "should visit_As" do
        as = Nodes::As.new(Arel.sql("foo"), Arel.sql("bar"))
        sql = @visitor.accept as
        sql.must_be_like "foo AS bar"
      end

      it "should visit_Bignum" do
        @visitor.accept 8787878092
      end

      it "should visit_Hash" do
        @visitor.accept({:a => 1})
      end

      it "should visit_BigDecimal" do
        @visitor.accept BigDecimal.new('2.14')
      end

      it "should visit_Date" do
        @visitor.accept Date.today
      end

      it "should visit_NilClass" do
        @visitor.accept(nil).must_be_like "NULL"
      end

      it "should visit_Arel_Nodes_And" do
        node = Nodes::And.new [@attr.eq(10), @attr.eq(11)]
        @visitor.accept(node).must_be_like %{
          "users"."id" = 10 AND "users"."id" = 11
        }
      end

      it "should visit_Arel_Nodes_Or" do
        node = Nodes::Or.new @attr.eq(10), @attr.eq(11)
        @visitor.accept(node).must_be_like %{
          "users"."id" = 10 OR "users"."id" = 11
        }
      end

      it "should visit visit_Arel_Attributes_Time" do
        attr = Attributes::Time.new(@attr.relation, @attr.name)
        @visitor.accept attr
      end

      it "should visit_TrueClass" do
        test = Table.new(:users)[:bool].eq(true)
        @visitor.accept(test).must_be_like %{ "users"."bool" = 't' }
      end

      describe "Nodes::Ordering" do
        it "should know how to visit" do
          node = @attr.desc
          @visitor.accept(node).must_be_like %{
            "users"."id" DESC
          }
        end
      end

      describe "Nodes::In" do
        it "should know how to visit" do
          node = @attr.in [1, 2, 3]
          @visitor.accept(node).must_be_like %{
            "users"."id" IN (1, 2, 3)
          }
        end

        it "should turn empty right to NULL" do
          node = @attr.in []
          @visitor.accept(node).must_be_like %{
            "users"."id" IN (NULL)
          }
        end

        it 'can handle two dot ranges' do
          node = @attr.in 1..3
          @visitor.accept(node).must_be_like %{
            "users"."id" BETWEEN 1 AND 3
          }
        end

        it 'can handle three dot ranges' do
          node = @attr.in 1...3
          @visitor.accept(node).must_be_like %{
            "users"."id" >= 1 AND "users"."id" < 3
          }
        end

        it 'can handle subqueries' do
          table = Table.new(:users)
          subquery = table.project(:id).where(table[:name].eq('Aaron'))
          node = @attr.in subquery
          @visitor.accept(node).must_be_like %{
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
          in_node = Nodes::In.new @attr, %w{ a b c }
          visitor = visitor.new(Table.engine.connection)
          visitor.expected = Table.engine.connection.columns(:users).find { |x|
            x.name == 'name'
          }
          visitor.accept(in_node).must_equal %("users"."name" IN ('a', 'b', 'c'))
        end
      end

      describe "Nodes::InfixOperation" do
        it "should handle Multiplication" do
          node = Arel::Attributes::Decimal.new(Table.new(:products), :price) * Arel::Attributes::Decimal.new(Table.new(:currency_rates), :rate)
          @visitor.accept(node).must_equal %("products"."price" * "currency_rates"."rate")
        end

        it "should handle Division" do
          node = Arel::Attributes::Decimal.new(Table.new(:products), :price) / 5
          @visitor.accept(node).must_equal %("products"."price" / 5)
        end

        it "should handle Addition" do
          node = Arel::Attributes::Decimal.new(Table.new(:products), :price) + 6
          @visitor.accept(node).must_equal %(("products"."price" + 6))
        end

        it "should handle Subtraction" do
          node = Arel::Attributes::Decimal.new(Table.new(:products), :price) - 7
          @visitor.accept(node).must_equal %(("products"."price" - 7))
        end

        it "should handle arbitrary operators" do
          node = Arel::Nodes::InfixOperation.new(
            '||',
            Arel::Attributes::String.new(Table.new(:products), :name),
            Arel::Attributes::String.new(Table.new(:products), :name)
          )
          @visitor.accept(node).must_equal %("products"."name" || "products"."name")
        end
      end

      describe "Nodes::NotIn" do
        it "should know how to visit" do
          node = @attr.not_in [1, 2, 3]
          @visitor.accept(node).must_be_like %{
            "users"."id" NOT IN (1, 2, 3)
          }
        end

        it "should turn empty right to NULL" do
          node = @attr.not_in []
          @visitor.accept(node).must_be_like %{
            "users"."id" NOT IN (NULL)
          }
        end

        it 'can handle two dot ranges' do
          node = @attr.not_in 1..3
          @visitor.accept(node).must_be_like %{
            "users"."id" < 1 OR "users"."id" > 3
          }
        end

        it 'can handle three dot ranges' do
          node = @attr.not_in 1...3
          @visitor.accept(node).must_be_like %{
            "users"."id" < 1 OR "users"."id" >= 3
          }
        end

        it 'can handle subqueries' do
          table = Table.new(:users)
          subquery = table.project(:id).where(table[:name].eq('Aaron'))
          node = @attr.not_in subquery
          @visitor.accept(node).must_be_like %{
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
          in_node = Nodes::NotIn.new @attr, %w{ a b c }
          visitor = visitor.new(Table.engine.connection)
          visitor.expected = Table.engine.connection.columns(:users).find { |x|
            x.name == 'name'
          }
          visitor.accept(in_node).must_equal %("users"."name" NOT IN ('a', 'b', 'c'))
        end
      end

      describe 'Equality' do
        it "should escape strings" do
          test = Table.new(:users)[:name].eq 'Aaron Patterson'
          @visitor.accept(test).must_be_like %{
            "users"."name" = 'Aaron Patterson'
          }
        end
      end

      describe 'Constants' do
        it "should handle true" do
          test = Table.new(:users).create_true
          @visitor.accept(test).must_be_like %{
            TRUE
          }
        end

        it "should handle false" do
          test = Table.new(:users).create_false
          @visitor.accept(test).must_be_like %{
            FALSE
          }
        end
      end

      describe 'TableAlias' do
        it "should use the underlying table for checking columns" do
          test = Table.new(:users).alias('zomgusers')[:id].eq '3'
          @visitor.accept(test).must_be_like %{
            "zomgusers"."id" = 3
          }
        end
      end

      describe 'distinct on' do
        it 'raises not implemented error' do
          core = Arel::Nodes::SelectCore.new
          core.set_quantifier = Arel::Nodes::DistinctOn.new(Arel.sql('aaron'))

          assert_raises(NotImplementedError) do
            @visitor.accept(core)
          end
        end
      end
    end
  end
end
