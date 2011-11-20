require 'helper'

module Arel
  module Visitors
    describe 'the join_sql visitor' do
      before do
        @visitor = ToSql.new Table.engine.connection
        @visitor.extend(JoinSql)
      end

      it 'should visit string join' do
        sql = @visitor.accept Nodes::StringJoin.new('omg')
        sql.must_be_like "'omg'"
      end

      describe 'inner join' do
        it 'should visit left if left is a join' do
          t    = Table.new :users
          sm   = t.select_manager
          sm.join(t).on(t[:id]).join(t).on(t[:id])
          sm.join_sql.must_be_like %{
            INNER JOIN "users" ON "users"."id"
            INNER JOIN "users" ON "users"."id"
          }
        end
      end

      describe 'outer join' do
        it 'should visit left if left is a join' do
          t    = Table.new :users
          sm   = t.select_manager
          sm.join(t, Nodes::OuterJoin).on(t[:id]).join(
            t, Nodes::OuterJoin).on(t[:id])
          sm.join_sql.must_be_like %{
            LEFT OUTER JOIN "users" ON "users"."id"
            LEFT OUTER JOIN "users" ON "users"."id"
          }
        end
      end
    end
  end
end
