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
end
