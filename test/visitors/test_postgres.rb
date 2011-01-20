require 'helper'

module Arel
  module Visitors
    describe 'the postgres visitor' do
      before do
        @visitor = PostgreSQL.new Table.engine
      end

      describe 'locking' do
        it 'defaults to FOR UPDATE' do
          @visitor.accept(Nodes::Lock.new).must_be_like %{
            FOR UPDATE
          }
        end

        it 'allows a custom string to be used as a lock' do
          node = Nodes::Lock.new('FOR SHARE')
          @visitor.accept(node).must_be_like %{
            FOR SHARE
          }
        end
      end

      it "should escape LIMIT" do
        sc = Arel::Nodes::SelectStatement.new
        sc.limit = Nodes::Limit.new("omg")
        sc.cores.first.projections << 'DISTINCT ON'
        sc.orders << "xyz"
        sql =  @visitor.accept(sc)
        assert_match(/LIMIT 'omg'/, sql)
        assert_equal 1, sql.scan(/LIMIT/).length, 'should have one limit'
      end
    end
  end
end
