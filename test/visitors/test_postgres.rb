require 'helper'

module Arel
  module Visitors
    describe 'the postgres visitor' do
      before do
        @visitor = PostgreSQL.new Table.engine
      end

      it 'should produce a lock value' do
        @visitor.accept(Nodes::Lock.new).must_be_like %{
          FOR UPDATE
        }
      end
    end
  end
end
