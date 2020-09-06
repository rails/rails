# frozen_string_literal: true

require_relative '../helper'

module Arel
  module Nodes
    class NodesTest < Arel::Spec
      describe 'Binary' do
        describe '#hash' do
          it 'generates a hash based on its value' do
            eq = Equality.new('foo', 'bar')
            eq2 = Equality.new('foo', 'bar')
            eq3 = Equality.new('bar', 'baz')

            assert_equal eq.hash, eq2.hash
            assert_not_equal eq.hash, eq3.hash
          end

          it 'generates a hash specific to its class' do
            eq = Equality.new('foo', 'bar')
            neq = NotEqual.new('foo', 'bar')

            assert_not_equal eq.hash, neq.hash
          end
        end
      end
    end
  end
end
