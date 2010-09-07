require 'spec_helper'

describe Arel::Nodes::Count do
  describe "as" do
    it 'should alias the count' do
      table = Arel::Table.new :users
      table[:id].count.as('foo').to_sql.should be_like %{
        COUNT("users"."id") AS foo
      }
    end
  end
end
