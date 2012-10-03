require 'cases/helper'

class HotCompatibilityTest < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  setup do
    @klass = Class.new(ActiveRecord::Base) do
      connection.create_table :hot_compatibilities do |t|
        t.string :foo
        t.string :bar
      end

      def self.name; 'HotCompatibility'; end
    end
  end

  teardown do
    @klass.connection.drop_table :hot_compatibilities
  end

  test "insert after remove_column" do
    # warm cache
    @klass.create!

    # we have 3 columns
    assert_equal 3, @klass.columns.length

    # remove one of them
    @klass.connection.remove_column :hot_compatibilities, :bar

    # we still have 3 columns in the cache
    assert_equal 3, @klass.columns.length

    # but we can successfully create a record so long as we don't
    # reference the removed column
    record = @klass.create! foo: 'foo'
    record.reload
    assert_equal 'foo', record.foo
  end

  test "update after remove_column" do
    record = @klass.create! foo: 'foo'
    assert_equal 3, @klass.columns.length
    @klass.connection.remove_column :hot_compatibilities, :bar
    assert_equal 3, @klass.columns.length

    record.reload
    assert_equal 'foo', record.foo
    record.foo = 'bar'
    record.save!
    record.reload
    assert_equal 'bar', record.foo
  end
end
