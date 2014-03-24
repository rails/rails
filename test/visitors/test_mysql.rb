require 'helper'

module Arel
  module Visitors
    describe 'the mysql visitor' do
      before do
        @visitor = MySQL.new Table.engine.connection
      end

      it 'squashes parenthesis on multiple unions' do
        subnode = Nodes::Union.new Arel.sql('left'), Arel.sql('right')
        node    = Nodes::Union.new subnode, Arel.sql('topright')
        assert_equal 1, @visitor.accept(node).scan('(').length

        subnode = Nodes::Union.new Arel.sql('left'), Arel.sql('right')
        node    = Nodes::Union.new Arel.sql('topleft'), subnode
        assert_equal 1, @visitor.accept(node).scan('(').length
      end

      ###
      # :'(
      # http://dev.mysql.com/doc/refman/5.0/en/select.html#id3482214
      it 'defaults limit to 18446744073709551615' do
        stmt = Nodes::SelectStatement.new
        stmt.offset = Nodes::Offset.new(1)
        sql = @visitor.accept(stmt)
        sql.must_be_like "SELECT FROM DUAL LIMIT 18446744073709551615 OFFSET 1"
      end

      it "should escape LIMIT" do
        sc = Arel::Nodes::UpdateStatement.new
        sc.relation = Table.new(:users)
        sc.limit = Nodes::Limit.new(Nodes.build_quoted("omg"))
        assert_equal("UPDATE \"users\" LIMIT 'omg'", @visitor.accept(sc))
      end

      it 'uses DUAL for empty from' do
        stmt = Nodes::SelectStatement.new
        sql = @visitor.accept(stmt)
        sql.must_be_like "SELECT FROM DUAL"
      end

      describe 'locking' do
        it 'defaults to FOR UPDATE when locking' do
          node = Nodes::Lock.new(Arel.sql('FOR UPDATE'))
          @visitor.accept(node).must_be_like "FOR UPDATE"
        end

        it 'allows a custom string to be used as a lock' do
          node = Nodes::Lock.new(Arel.sql('LOCK IN SHARE MODE'))
          @visitor.accept(node).must_be_like "LOCK IN SHARE MODE"
        end
      end
    end
  end
end
