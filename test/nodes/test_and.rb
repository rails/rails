require 'helper'

module Arel
  module Nodes
    describe 'And' do
      describe 'equality' do
        it 'is equal with equal ivars' do
          array = [And.new(['foo', 'bar']), And.new(['foo', 'bar'])]
          assert_equal 1, array.uniq.size
        end

        it 'is not equal with different ivars' do
          array = [And.new(['foo', 'bar']), And.new(['foo', 'baz'])]
          assert_equal 2, array.uniq.size
        end
      end
    end
  end
end

