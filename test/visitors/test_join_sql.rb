require 'helper'

module Arel
  module Visitors
    describe 'the join_sql visitor' do
      before do
        @visitor = JoinSql.new Table.engine
      end

      describe 'inner join' do
        it 'should visit left if left is a join' do
          t    = Table.new :users
          join = Nodes::InnerJoin.new t, t, Nodes::On.new(t[:id])
          j2   = Nodes::InnerJoin.new join, t, Nodes::On.new(t[:id])
          @visitor.accept(j2).must_be_like %{
            INNER JOIN "users" ON "users"."id"
            INNER JOIN "users" ON "users"."id"
          }
        end
      end

      describe 'outer join' do
        it 'should visit left if left is a join' do
          t    = Table.new :users
          join = Nodes::OuterJoin.new t, t, Nodes::On.new(t[:id])
          j2   = Nodes::OuterJoin.new join, t, Nodes::On.new(t[:id])
          @visitor.accept(j2).must_be_like %{
            LEFT OUTER JOIN "users" ON "users"."id"
            LEFT OUTER JOIN "users" ON "users"."id"
          }
        end
      end
    end
  end
end
