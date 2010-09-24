require 'spec_helper'

module Arel
  module Visitors
    describe 'the oracle visitor' do
      before do
        @visitor = Oracle.new Table.engine
      end

      describe 'Nodes::SelectStatement' do
        describe 'limit' do
          it 'adds a rownum clause' do
            stmt = Nodes::SelectStatement.new
            stmt.limit = 10
            sql = @visitor.accept stmt
            sql.should be_like %{ SELECT WHERE ROWNUM <= 10 }
          end
        end
      end
    end
  end
end
