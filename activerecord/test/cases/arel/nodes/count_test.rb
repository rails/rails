# frozen_string_literal: true
require_relative '../helper'

class Arel::Nodes::CountTest < Arel::Spec
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

  describe 'equality' do
    it 'is equal with equal ivars' do
      array = [Arel::Nodes::Count.new('foo'), Arel::Nodes::Count.new('foo')]
      assert_equal 1, array.uniq.size
    end

    it 'is not equal with different ivars' do
      array = [Arel::Nodes::Count.new('foo'), Arel::Nodes::Count.new('foo!')]
      assert_equal 2, array.uniq.size
    end
  end

  describe 'math' do
    it 'allows mathematical functions' do
      table = Arel::Table.new :users
      (table[:id].count + 1).to_sql.must_be_like %{
        (COUNT("users"."id") + 1)
      }
    end
  end
end
