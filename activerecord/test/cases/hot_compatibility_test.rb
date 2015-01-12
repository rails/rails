require 'cases/helper'

class HotCompatibilityTest < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  setup do
    @klass = Class.new(ActiveRecord::Base) do
      connection.create_table :hot_compatibilities, force: true do |t|
        t.string :foo
        t.string :bar
      end

      def self.name; 'HotCompatibility'; end
    end

    @klass_owned = Class.new(ActiveRecord::Base) do
      connection.create_table :owned_hot_compatibilities, force: true do |t|
        t.string :foo
        t.string :baz
        t.references :owner_hot_compatibility
      end

      belongs_to :owner_hot_compatibility

      # Overriding default_select_column is currently necessary for hot
      # compatability on SELECT on some engines with prepared statements enabled.
      def self.default_select_columns
        @default_select_columns ||=
          connection.schema_cache.columns(table_name)
          .map { |c| arel_table[c.name] }
      end

      def self.name; 'OwnedHotCompatibility'; end
    end
    klass_owned = @klass_owned

    @klass_owner = Class.new(ActiveRecord::Base) do
      connection.create_table :owner_hot_compatibilities, force: true do |t|
        t.string :bar
      end

      has_many :foo_related, -> {where(foo: "foo")}, class: klass_owned

      def self.default_select_columns
        @default_select_columns ||=
          connection.schema_cache.columns(table_name)
          .map { |c| arel_table[c.name] }
      end

      def self.name; 'OwnerHotCompatibility'; end
    end
  end

  teardown do
    [:hot_compatibilities,
     :owned_hot_compatibilities,
     :owner_hot_compatibilities].each do |table|
      ActiveRecord::Base.connection.drop_table table
    end
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

  test "select after add_column" do
    record = @klass_owner.create! bar: 'bar'

    # do a reload to prepare the reload statement
    record.reload

    # add a new column
    @klass_owner.connection.add_column :owner_hot_compatibilities, :baz, :string

    # we can still reload the object
    record.reload

    assert_equal 'bar', record.bar
  end

  test "select in transaction after add_column" do
    record = @klass_owner.create! bar: 'bar'

    # prepare the reload statement in a transaction
    @klass_owner.transaction do
      record.reload
    end

    # add a new column
    @klass_owner.connection.add_column :owner_hot_compatibilities, :baz, :string

    # we can still reload the object in a transaction
    @klass_owner.transaction do
      record.reload
      assert_equal 'bar', record.bar
    end
  end

  test "association preload with conditions after add column" do
    owner_record = @klass_owner.create! bar: 'bar'

    owner_record.foo_related.create! baz: 'baz'

    # prepare the association preload statement
    @klass_owner.transaction do
      records = @klass_owner
        .preload(:foo_related).where(bar: 'bar').to_a
      assert_equal 1, records.size
      assert_equal 'bar', records[0].bar
      assert_equal 1, records[0].foo_related.size
      assert_equal 'baz', records[0].foo_related[0].baz
    end

    # add a column
    @klass_owned.connection.add_column :owned_hot_compatibilities, :qux, :string

    # we can still do the association preload statement
    @klass_owner.transaction do
      records = @klass_owner.preload(:foo_related).where(bar: 'bar').to_a
      assert_equal 1, records.size
      assert_equal 'bar', records[0].bar
      assert_equal 1, records[0].foo_related.size
      assert_equal 'baz', records[0].foo_related[0].baz
    end
  end
end
