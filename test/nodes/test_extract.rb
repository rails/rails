require 'helper'

describe Arel::Nodes::Extract do
  it "should extract field" do
    table = Arel::Table.new :users
    table[:timestamp].extract('date').to_sql.must_be_like %{
      EXTRACT(DATE FROM "users"."timestamp")
    }
  end

  describe "as" do
    it 'should alias the extract' do
      table = Arel::Table.new :users
      table[:timestamp].extract('date').as('foo').to_sql.must_be_like %{
        EXTRACT(DATE FROM "users"."timestamp") AS foo
      }
    end
  end

  describe 'equality' do
    it 'is equal with equal ivars' do
      table = Arel::Table.new :users
      array = [table[:attr].extract('foo'), table[:attr].extract('foo')]
      assert_equal 1, array.uniq.size
    end

    it 'is not equal with different ivars' do
      table = Arel::Table.new :users
      array = [table[:attr].extract('foo'), table[:attr].extract('bar')]
      assert_equal 2, array.uniq.size
    end
  end
end
