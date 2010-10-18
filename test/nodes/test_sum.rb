require 'helper'

describe Arel::Nodes::Sum do
  describe "as" do
    it 'should alias the sum' do
      table = Arel::Table.new :users
      table[:id].sum.as('foo').to_sql.must_be_like %{
        SUM("users"."id") AS foo
      }
    end
  end
end
