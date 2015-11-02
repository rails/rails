require 'cases/helper'
require 'support/connection_helper'

class HotCompatibilityTest < ActiveRecord::TestCase
  self.use_transactional_tests = false
  include ConnectionHelper

  setup do
    @klass = Class.new(ActiveRecord::Base) do
      connection.create_table :hot_compatibilities, force: true do |t|
        t.string :foo
        t.string :bar
      end

      def self.name; 'HotCompatibility'; end
    end

    @klass_owner = Class.new(ActiveRecord::Base) do
      connection.create_table :owner_hot_compatibilities, force: true do |t|
        t.string :bar
      end

      def self.name; 'OwnerHotCompatibility'; end
    end
  end

  teardown do
    [:hot_compatibilities,
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

  test "select in transaction after add_column" do
    # Rails will clear the prepared statements on the connection that runs the
    # migration, so we use two connections to simulate what would actually happen
    # on a production system; we'd have one connection running the migration from
    # the rake task ("ddl_connection" here), and we'd have another conneciton in the
    # web workers.
    run_without_connection do |original_connection|
      ActiveRecord::Base.establish_connection(original_connection.merge(pool_size: 2))
      begin
        ddl_connection = ActiveRecord::Base.connection_pool.checkout
        begin
          record = @klass_owner.create! bar: 'bar'

          # prepare the reload statement in a transaction
          @klass_owner.transaction do
            record.reload
          end

          # add a new column
          ddl_connection.add_column :owner_hot_compatibilities, :baz, :string

          # we can still reload the object in a transaction
          3.times do
            begin
              @klass_owner.transaction do
                record.reload
                assert_equal 'bar', record.bar
              end
            rescue
            end
          end

          @klass_owner.transaction do
            record.reload
            assert_equal 'bar', record.bar
          end

        ensure
          ActiveRecord::Base.connection_pool.checkin ddl_connection
        end
      ensure
        ActiveRecord::Base.clear_all_connections!
      end
    end
  end
end
