require 'helper'

module Arel
  module Nodes
    describe 'sql literal' do
      describe 'sql' do
        it 'makes a sql literal node' do
          sql = Arel.sql 'foo'
          sql.must_be_kind_of Arel::Nodes::SqlLiteral
        end
      end

      describe 'count' do
        it 'makes a count node' do
          node = SqlLiteral.new('*').count
          viz = Visitors::ToSql.new Table.engine
          viz.accept(node).must_be_like %{ COUNT(*) }
        end

        it 'makes a distinct node' do
          node = SqlLiteral.new('*').count true
          viz = Visitors::ToSql.new Table.engine
          viz.accept(node).must_be_like %{ COUNT(DISTINCT *) }
        end
      end

      describe 'equality' do
        it 'makes an equality node' do
          node = SqlLiteral.new('foo').eq(1)
          viz = Visitors::ToSql.new Table.engine
          viz.accept(node).must_be_like %{ foo = 1 }
        end
      end

      describe 'grouped "or" equality' do
        it 'makes a grouping node with an or node' do
          node = SqlLiteral.new('foo').eq_any([1,2])
          viz = Visitors::ToSql.new Table.engine
          viz.accept(node).must_be_like %{ (foo = 1 OR foo = 2) }
        end
      end

      describe 'grouped "and" equality' do
        it 'makes a grouping node with an or node' do
          node = SqlLiteral.new('foo').eq_all([1,2])
          viz = Visitors::ToSql.new Table.engine
          viz.accept(node).must_be_like %{ (foo = 1 AND foo = 2) }
        end
      end
    end
  end
end
