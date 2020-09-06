# frozen_string_literal: true

require_relative 'helper'

module Arel
  describe 'Attributes' do
    it 'responds to lower' do
      relation  = Table.new(:users)
      attribute = relation[:foo]
      node      = attribute.lower
      assert_equal 'LOWER', node.name
      assert_equal [attribute], node.expressions
    end

    describe 'equality' do
      it 'is equal with equal ivars' do
        array = [Attribute.new('foo', 'bar'), Attribute.new('foo', 'bar')]
        assert_equal 1, array.uniq.size
      end

      it 'is not equal with different ivars' do
        array = [Attribute.new('foo', 'bar'), Attribute.new('foo', 'baz')]
        assert_equal 2, array.uniq.size
      end
    end
  end
end
