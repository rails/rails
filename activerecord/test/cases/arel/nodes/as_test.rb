# frozen_string_literal: true
require_relative '../helper'

module Arel
  module Nodes
    describe 'As' do
      describe '#as' do
        it 'makes an AS node' do
          attr = Table.new(:users)[:id]
          as = attr.as(Arel.sql('foo'))
          assert_equal attr, as.left
          assert_equal 'foo', as.right
        end

        it 'converts right to SqlLiteral if a string' do
          attr = Table.new(:users)[:id]
          as = attr.as('foo')
          assert_kind_of Arel::Nodes::SqlLiteral, as.right
        end
      end

      describe 'equality' do
        it 'is equal with equal ivars' do
          array = [As.new('foo', 'bar'), As.new('foo', 'bar')]
          assert_equal 1, array.uniq.size
        end

        it 'is not equal with different ivars' do
          array = [As.new('foo', 'bar'), As.new('foo', 'baz')]
          assert_equal 2, array.uniq.size
        end
      end
    end
  end
end
