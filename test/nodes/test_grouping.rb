require 'helper'

module Arel
  module Nodes
    describe 'Grouping' do
      it 'should create Equality nodes' do
        grouping = Grouping.new('foo')
        grouping.eq('foo').to_sql.must_be_like %q{('foo') = 'foo'}
      end
    end
  end
end

