require 'test_helper'

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
    end
  end
end
