require 'helper'

describe Arel::Nodes::Count do
  describe 'backwards compatibility' do
    it 'must be an expression' do
      Arel::Nodes::Count.new('foo').must_be_kind_of Arel::Expression
    end
  end

  describe "as" do
    it 'should alias the count' do
      table = Arel::Table.new :users
      table[:id].count.as('foo').to_sql.must_be_like %{
        COUNT("users"."id") AS foo
      }
    end
  end

  describe "eq" do
    it "should compare the count" do
      table = Arel::Table.new :users
      table[:id].count.eq(2).to_sql.must_be_like %{
        COUNT("users"."id") = 2
      }
    end
  end
end
