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

  describe 'equality' do
    it 'is equal with equal ivars' do
      array = [Arel::Nodes::Sum.new('foo'), Arel::Nodes::Sum.new('foo')]
      assert_equal 1, array.uniq.size
    end

    it 'is not equal with different ivars' do
      array = [Arel::Nodes::Sum.new('foo'), Arel::Nodes::Sum.new('foo!')]
      assert_equal 2, array.uniq.size
    end
  end
end
