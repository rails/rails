require 'helper'

module Arel
  module Visitors
    describe 'the oracle visitor' do
      before do
        @visitor = Oracle12.new Table.engine.connection_pool
      end

      def compile node
        @visitor.accept(node, Collectors::SQLString.new).value
      end

      it 'modified except to be minus' do
        left = Nodes::SqlLiteral.new("SELECT * FROM users WHERE age > 10")
        right = Nodes::SqlLiteral.new("SELECT * FROM users WHERE age > 20")
        sql = compile Nodes::Except.new(left, right)
        sql.must_be_like %{
          ( SELECT * FROM users WHERE age > 10 MINUS SELECT * FROM users WHERE age > 20 )
        }
      end

      it 'generates select options offset then limit' do
        stmt = Nodes::SelectStatement.new
        stmt.offset = Nodes::Offset.new(1)
        stmt.limit = Nodes::Limit.new(Nodes.build_quoted(10))
        sql = compile(stmt)
        sql.must_be_like "SELECT OFFSET 1 ROWS FETCH FIRST 10 ROWS ONLY"
      end

      describe 'locking' do
        it 'removes limit when locking' do
          stmt = Nodes::SelectStatement.new
          stmt.limit = Nodes::Limit.new(Nodes.build_quoted(10))
          stmt.lock = Nodes::Lock.new(Arel.sql('FOR UPDATE'))
          sql = compile(stmt)
          sql.must_be_like "SELECT FOR UPDATE"
        end

        it 'defaults to FOR UPDATE when locking' do
          node = Nodes::Lock.new(Arel.sql('FOR UPDATE'))
          compile(node).must_be_like "FOR UPDATE"
        end
      end
    end
  end
end
