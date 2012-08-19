require 'helper'

module Arel
  module Nodes
    describe 'Grouping' do
      it 'should create Equality nodes' do
        grouping = Grouping.new('foo')
        grouping.eq('foo').to_sql.must_be_like %q{('foo') = 'foo'}
      end

      describe 'equality' do
        it 'is equal with equal ivars' do
          array = [Grouping.new('foo'), Grouping.new('foo')]
          assert_equal 1, array.uniq.size
        end

        it 'is not equal with different ivars' do
          array = [Grouping.new('foo'), Grouping.new('bar')]
          assert_equal 2, array.uniq.size
        end
      end
    end
  end
end

