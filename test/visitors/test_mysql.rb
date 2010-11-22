require 'helper'

module Arel
  module Visitors
    describe 'the mysql visitor' do
      before do
        @visitor = MySQL.new Table.engine
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

      it 'uses DUAL for empty from' do
        stmt = Nodes::SelectStatement.new
        sql = @visitor.accept(stmt)
        sql.must_be_like "SELECT FROM DUAL"
      end

      it 'uses FOR UPDATE when locking' do
        stmt = Nodes::SelectStatement.new
        stmt.lock = Nodes::Lock.new
        sql = @visitor.accept(stmt)
        sql.must_be_like "SELECT FROM DUAL FOR UPDATE"
      end
    end
  end
end
