require 'spec_helper'

describe Arel::Nodes::Count do
  describe 'backwards compatibility' do
    it 'must be an expression' do
      Arel::Nodes::Count.new('foo').should be_kind_of Arel::Expression
    end
  end

  describe "as" do
    it 'should alias the count' do
      table = Arel::Table.new :users
      table[:id].count.as('foo').to_sql.should be_like %{
        COUNT("users"."id") AS foo
      }
    end
  end
end
