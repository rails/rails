# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"

class HotCompatibilityTest < ActiveRecord::TestCase
  skip_under_ractor_proxy

  self.use_transactional_tests = false
  include ConnectionHelper

  setup do
    @klass = Class.new(ActiveRecord::Base) do
      lease_connection.create_table :hot_compatibilities, force: true do |t|
        t.string :foo
        t.string :bar
      end

      def self.name; "HotCompatibility"; end
    end
  end

  teardown do
    ActiveRecord::Base.lease_connection.drop_table :hot_compatibilities
    @klass.reset_column_information
  end

  test "insert after remove_column" do
    # warm cache
    @klass.create!

    # we have 3 columns
    assert_equal 3, @klass.columns.length

    # remove one of them
    @klass.lease_connection.remove_column :hot_compatibilities, :bar

    # we still have 3 columns in the cache
    assert_equal 3, @klass.columns.length

    # but we can successfully create a record so long as we don't
    # reference the removed column
    record = @klass.create! foo: "foo"
    record.reload
    assert_equal "foo", record.foo
  end

  test "update after remove_column" do
    record = @klass.create! foo: "foo"
    assert_equal 3, @klass.columns.length
    @klass.lease_connection.remove_column :hot_compatibilities, :bar
    assert_equal 3, @klass.columns.length

    record.reload
    assert_equal "foo", record.foo
    record.foo = "bar"
    record.save!
    record.reload
    assert_equal "bar", record.foo
  end

  test "read a record loaded before remove_column and reset_column_information" do
    @klass.create!(foo: "foo", bar: "bar")
    record = @klass.first

    @klass.lease_connection.remove_column :hot_compatibilities, :foo
    @klass.reset_column_information
    @klass.first

    assert_equal "bar", record.bar
    record.bar = "changed"
    assert_equal "changed", record.bar
  end

  test "read a record loaded before add_column and reset_column_information" do
    @klass.create!(foo: "foo", bar: "bar")
    record = @klass.first

    @klass.lease_connection.add_column :hot_compatibilities, :baz, :string
    @klass.reset_column_information
    @klass.first

    assert_equal "foo", record.foo
    assert_equal "bar", record.bar
  end

  test "read an added column on a record loaded with extra select columns" do
    @klass.create!
    record = @klass.select("hot_compatibilities.*, 1 AS one").first

    @klass.lease_connection.add_column :hot_compatibilities, :baz, :string
    @klass.reset_column_information
    @klass.first

    assert_nil record.baz
    assert_equal 1, record.one
  end

  test "read a record loaded with extra select columns before reset_column_information" do
    @klass.create!(foo: "foo", bar: "bar")
    record = @klass.select("hot_compatibilities.*, 1 AS one").first

    @klass.lease_connection.remove_column :hot_compatibilities, :foo
    @klass.reset_column_information
    @klass.first

    assert_equal "bar", record.bar
    assert_equal 1, record.one
  end

  test "read a declared attribute of a record loaded before add_column and reset_column_information" do
    @klass.attribute :virtual, :string
    @klass.create!(foo: "foo")
    record = @klass.first
    record.virtual = "virtual"

    @klass.lease_connection.add_column :hot_compatibilities, :baz, :string
    @klass.reset_column_information
    @klass.first

    assert_equal "virtual", record.virtual
  end

  test "read a declared attribute that moves back after reset_column_information" do
    @klass.attribute :virtual, :string
    @klass.create!(foo: "foo")
    @klass.lease_connection.add_column :hot_compatibilities, :baz, :string
    @klass.reset_column_information
    record = @klass.first
    record.virtual = "virtual"

    @klass.lease_connection.remove_column :hot_compatibilities, :baz
    @klass.reset_column_information
    @klass.first

    assert_equal "virtual", record.virtual
  end

  if current_adapter?(:PostgreSQLAdapter) && ActiveRecord::Base.lease_connection.prepared_statements
    test "cleans up after prepared statement failure in a transaction" do
      with_two_connections do |original_connection, ddl_connection|
        record = @klass.create! bar: "bar"

        # prepare the reload statement in a transaction
        @klass.transaction do
          record.reload
        end

        assert_predicate get_prepared_statement_cache(@klass.lease_connection), :any?,
          "expected prepared statement cache to have something in it"

        # add a new column
        ddl_connection.add_column :hot_compatibilities, :baz, :string

        assert_raise(ActiveRecord::PreparedStatementCacheExpired) do
          @klass.transaction do
            record.reload
          end
        end

        assert_empty get_prepared_statement_cache(@klass.lease_connection),
          "expected prepared statement cache to be empty but it wasn't"
      end
    end

    test "cleans up after prepared statement failure in nested transactions" do
      with_two_connections do |original_connection, ddl_connection|
        record = @klass.create! bar: "bar"

        # prepare the reload statement in a transaction
        @klass.transaction do
          record.reload
        end

        assert_predicate get_prepared_statement_cache(@klass.lease_connection), :any?,
          "expected prepared statement cache to have something in it"

        # add a new column
        ddl_connection.add_column :hot_compatibilities, :baz, :string

        assert_raise(ActiveRecord::PreparedStatementCacheExpired) do
          @klass.transaction do
            @klass.transaction do
              @klass.transaction do
                record.reload
              end
            end
          end
        end

        assert_empty get_prepared_statement_cache(@klass.lease_connection),
          "expected prepared statement cache to be empty but it wasn't"
      end
    end
  end

  private
    def get_prepared_statement_cache(connection)
      connection.instance_variable_get(:@statements)
        .instance_variable_get(:@cache)[Process.pid]
    end

    # Rails will automatically clear the prepared statements on the connection
    # that runs the migration, so we use two connections to simulate what would
    # actually happen on a production system; we'd have one connection running the
    # migration from the rake task ("ddl_connection" here), and we'd have another
    # connection in a web worker.
    def with_two_connections
      run_without_connection do |original_connection|
        ActiveRecord::Base.establish_connection(original_connection.merge(pool_size: 2))
        begin
          ddl_connection = ActiveRecord::Base.connection_pool.checkout
          begin
            yield original_connection, ddl_connection
          ensure
            ActiveRecord::Base.connection_pool.checkin ddl_connection
          end
        ensure
          ActiveRecord::Base.connection_handler.clear_all_connections!(:all)
        end
      end
    end
end
