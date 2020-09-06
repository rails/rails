# frozen_string_literal: true

require_relative '../helper'

class Arel::Nodes::OverTest < Arel::Spec
  describe 'as' do
    it 'should alias the expression' do
      table = Arel::Table.new :users
      _(table[:id].count.over.as('foo').to_sql).must_be_like %{
        COUNT("users"."id") OVER () AS foo
      }
    end
  end

  describe 'with literal' do
    it 'should reference the window definition by name' do
      table = Arel::Table.new :users
      _(table[:id].count.over('foo').to_sql).must_be_like %{
        COUNT("users"."id") OVER "foo"
      }
    end
  end

  describe 'with SQL literal' do
    it 'should reference the window definition by name' do
      table = Arel::Table.new :users
      _(table[:id].count.over(Arel.sql('foo')).to_sql).must_be_like %{
        COUNT("users"."id") OVER foo
      }
    end
  end

  describe 'with no expression' do
    it 'should use empty definition' do
      table = Arel::Table.new :users
      _(table[:id].count.over.to_sql).must_be_like %{
        COUNT("users"."id") OVER ()
      }
    end
  end

  describe 'with expression' do
    it 'should use definition in sub-expression' do
      table = Arel::Table.new :users
      window = Arel::Nodes::Window.new.order(table['foo'])
      _(table[:id].count.over(window).to_sql).must_be_like %{
        COUNT("users"."id") OVER (ORDER BY \"users\".\"foo\")
      }
    end
  end

  describe 'equality' do
    it 'is equal with equal ivars' do
      array = [
        Arel::Nodes::Over.new('foo', 'bar'),
        Arel::Nodes::Over.new('foo', 'bar')
      ]
      assert_equal 1, array.uniq.size
    end

    it 'is not equal with different ivars' do
      array = [
        Arel::Nodes::Over.new('foo', 'bar'),
        Arel::Nodes::Over.new('foo', 'baz')
      ]
      assert_equal 2, array.uniq.size
    end
  end
end
