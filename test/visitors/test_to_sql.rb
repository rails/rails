require 'helper'

module Arel
  module Visitors
    describe 'the to_sql visitor' do
      before do
        @visitor = ToSql.new Table.engine
        @attr = Table.new(:users)[:id]
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

      it "should visit_DateTime" do
        @visitor.accept DateTime.now
      end

      it "should visit_Float" do
        @visitor.accept 2.14
      end

      it "should visit_Not" do
        sql = @visitor.accept Nodes::Not.new(Arel.sql("foo"))
        sql.must_be_like "NOT foo"
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
        node = Nodes::And.new @attr.eq(10), @attr.eq(11)
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
        attr = Attributes::Time.new(@attr.relation, @attr.name, @attr.column)
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
          visitor = visitor.new(Table.engine)
          visitor.expected = @attr.column
          visitor.accept(in_node).must_equal %("users"."name" IN ('a', 'b', 'c'))
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
          visitor = visitor.new(Table.engine)
          visitor.expected = @attr.column
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
    end
  end
end
