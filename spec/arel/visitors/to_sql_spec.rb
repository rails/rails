require 'spec_helper'

module Arel
  module Visitors
    describe 'the to_sql visitor' do
      before do
        @visitor = ToSql.new Table.engine
        @attr = Table.new(:users)[:id]
      end

      it "should visit_BigDecimal" do
        @visitor.accept BigDecimal.new('2.14')
      end

      it "should visit_Date" do
        @visitor.accept Date.today
      end

      it "should visit_Arel_Nodes_And" do
        node = Nodes::And.new @attr.eq(10), @attr.eq(11)
        @visitor.accept(node).should be_like %{
          "users"."id" = 10 AND "users"."id" = 11
        }
      end

      it "should visit_Arel_Nodes_Or" do
        node = Nodes::Or.new @attr.eq(10), @attr.eq(11)
        @visitor.accept(node).should be_like %{
          "users"."id" = 10 OR "users"."id" = 11
        }
      end

      it "should visit visit_Arel_Attributes_Time" do
        attr = Attributes::Time.new(@attr.relation, @attr.name, @attr.column)
        @visitor.accept attr
      end

      it "should visit_TrueClass" do
        @visitor.accept(@attr.eq(true)).should be_like %{ "users"."id" = 't' }
      end

      describe "Nodes::In" do
        it "should know how to visit" do
          node = @attr.in [1, 2, 3]
          @visitor.accept(node).should be_like %{
            "users"."id" IN (1, 2, 3)
          }
        end
      end

      describe 'Equality' do
        it "should escape strings" do
          test = @attr.eq 'Aaron Patterson'
          @visitor.accept(test).should be_like %{
            "users"."id" = 'Aaron Patterson'
          }
        end
      end
    end
  end
end
