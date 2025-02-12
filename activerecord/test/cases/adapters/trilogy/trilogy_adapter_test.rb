# frozen_string_literal: true

require "cases/helper"
require "support/ddl_helper"
require "models/book"
require "models/post"
require "timeout"

class TrilogyAdapterTest < ActiveRecord::TrilogyTestCase
  setup do
    @conn = ActiveRecord::Base.lease_connection
  end

  test "connection_error" do
    error = assert_raises ActiveRecord::ConnectionNotEstablished do
      ActiveRecord::ConnectionAdapters::TrilogyAdapter.new(host: "invalid", port: 12345).connect!
    end
    assert_kind_of ActiveRecord::ConnectionAdapters::NullPool, error.connection_pool
  end

  test "timeout in transaction doesnt query closed connection" do
    assert_raises(Timeout::Error) do
      Timeout.timeout(0.1) do
        @conn.transaction do
          @conn.execute("SELECT SLEEP(1)")
        end
      end
    end
  end

  test "timeout in fixture set insertion doesnt query closed connection" do
    fixtures = [
      ["traffic_lights", [
        { "location" => "US", "state" => ["NY"], "long_state" => ["a"] },
      ]]
    ] * 1000

    assert_raises(Timeout::Error) do
      Timeout.timeout(0.1) do
        @conn.insert_fixtures_set(fixtures)
      end
    end
  end

  test "timeout without referential integrity doesnt query closed connection" do
    assert_raises(Timeout::Error) do
      Timeout.timeout(0.1) do
        @conn.disable_referential_integrity do
          @conn.execute("SELECT SLEEP(1)")
        end
      end
    end
  end

  test "#explain for one query" do
    explain = @conn.explain("select * from posts")
    assert_match %(possible_keys), explain
  end

  test "#adapter_name answers name" do
    assert_equal "Trilogy", @conn.adapter_name
  end

  test "#supports_json answers true without Maria DB and greater version" do
    @conn.stub(:mariadb?, false) do
      assert_equal true, @conn.supports_json?
    end
  end

  test "#supports_json answers false without Maria DB and lesser version" do
    database_version = @conn.class::Version.new("5.0.0", nil)

    @conn.stub(:database_version, database_version) do
      assert_equal false, @conn.supports_json?
    end
  end

  test "#supports_json answers false with Maria DB" do
    @conn.stub(:mariadb?, true) do
      assert_equal false, @conn.supports_json?
    end
  end

  test "#supports_comments? answers true" do
    assert_predicate @conn, :supports_comments?
  end

  test "#supports_comments_in_create? answers true" do
    assert_predicate @conn, :supports_comments_in_create?
  end

  test "#supports_savepoints? answers true" do
    assert_predicate @conn, :supports_savepoints?
  end

  test "#requires_reloading? answers false" do
    assert_equal false, @conn.requires_reloading?
  end

  test "#native_database_types answers known types" do
    assert_equal ActiveRecord::ConnectionAdapters::TrilogyAdapter::NATIVE_DATABASE_TYPES, @conn.native_database_types
  end

  test "#quote_column_name answers quoted string when not quoted" do
    assert_equal "`test`", @conn.quote_column_name("test")
  end

  test "#quote_column_name answers triple quoted string when quoted" do
    assert_equal "```test```", @conn.quote_column_name("`test`")
  end

  test "#quote_column_name answers quoted string for integer" do
    assert_equal "`1`", @conn.quote_column_name(1)
  end

  test "#quote_string answers string with connection" do
    assert_equal "\\\"test\\\"", @conn.quote_string(%("test"))
  end

  test "#quoted_true answers TRUE" do
    assert_equal "TRUE", @conn.quoted_true
  end

  test "#quoted_false answers FALSE" do
    assert_equal "FALSE", @conn.quoted_false
  end

  test "#active? answers true with connection" do
    assert_predicate @conn, :active?
  end

  test "#active? answers false with connection and exception" do
    @conn.instance_variable_get(:@raw_connection).stub(:ping, -> { raise ::Trilogy::BaseError.new }) do
      assert_equal false, @conn.active?
    end
  end

  test "#reconnect answers new connection with existing connection" do
    old_connection = @conn.instance_variable_get(:@raw_connection)
    @conn.reconnect!
    connection = @conn.instance_variable_get(:@raw_connection)

    assert_instance_of Trilogy, connection
    assert_not_equal old_connection, connection
  end

  test "#reset answers new connection with existing connection" do
    old_connection = @conn.instance_variable_get(:@raw_connection)
    @conn.reset!
    connection = @conn.instance_variable_get(:@raw_connection)

    assert_instance_of Trilogy, connection
    assert_not_equal old_connection, connection
  end

  test "#disconnect makes adapter inactive with connection" do
    @conn.disconnect!
    assert_equal false, @conn.active?
  end

  test "#disconnect answers nil with connection" do
    assert_nil @conn.disconnect!
  end

  test "#discard answers nil with connection" do
    assert_nil @conn.discard!
  end

  test "#discard makes adapter inactive with connection" do
    @conn.discard!
    assert_equal false, @conn.active?
  end

  test "#exec_query fails with invalid query" do
    error = assert_raises ActiveRecord::StatementInvalid, match: /'activerecord_unittest.bogus' doesn't exist/ do
      @conn.exec_query "SELECT * FROM bogus;"
    end
    assert_equal @conn.pool, error.connection_pool
  end

  test "#execute answers results for valid query" do
    result = @conn.execute "SELECT id, author_id, title, body FROM posts;"
    assert_equal %w[id author_id title body], result.fields
  end

  test "#execute fails with invalid query" do
    error = assert_raises ActiveRecord::StatementInvalid, match: /Table 'activerecord_unittest.bogus' doesn't exist/ do
      @conn.execute "SELECT * FROM bogus;"
    end
    assert_equal @conn.pool, error.connection_pool
  end

  test "#execute fails with invalid SQL" do
    error = assert_raises(ActiveRecord::StatementInvalid) do
      @conn.execute "SELECT bogus FROM posts;"
    end

    assert_equal @conn.pool, error.connection_pool
  end

  test "#select_all when query cache is enabled fires the same notification payload for uncached and cached queries" do
    @conn.cache do
      event_fired = false
      subscription = ->(name, start, finish, id, payload) {
        next if payload[:name] == "SCHEMA"

        event_fired = true

        # First, we test keys that are defined by default by the AbstractAdapter
        assert_includes payload, :sql
        assert_equal "SELECT * FROM posts", payload[:sql]

        assert_includes payload, :name
        assert_equal "uncached query", payload[:name]

        assert_includes payload, :connection
        assert_equal @conn, payload[:connection]

        assert_includes payload, :binds
        assert_equal [], payload[:binds]

        assert_includes payload, :type_casted_binds
        assert_equal [], payload[:type_casted_binds]

        assert_nil payload[:statement_name]

        assert_not_includes payload, :cached
      }
      ActiveSupport::Notifications.subscribed(subscription, "sql.active_record") do
        @conn.select_all "SELECT * FROM posts", "uncached query"
      end
      assert event_fired

      event_fired = false
      subscription = ->(name, start, finish, id, payload) {
        next if payload[:name] == "SCHEMA"

        event_fired = true

        # First, we test keys that are defined by default by the AbstractAdapter
        assert_includes payload, :sql
        assert_equal "SELECT * FROM posts", payload[:sql]

        assert_includes payload, :name
        assert_equal "cached query", payload[:name]

        assert_includes payload, :connection
        assert_equal @conn, payload[:connection]

        assert_includes payload, :binds
        assert_equal [], payload[:binds]

        assert_includes payload, :type_casted_binds
        assert_equal [], payload[:type_casted_binds].is_a?(Proc) ? payload[:type_casted_binds].call : payload[:type_casted_binds]

        # Rails does not include :stament_name for cached queries 🤷‍♂️
        assert_not_includes payload, :statement_name

        assert_includes payload, :cached
        assert_equal true, payload[:cached]
      }
      ActiveSupport::Notifications.subscribed(subscription, "sql.active_record") do
        @conn.select_all "SELECT * FROM posts", "cached query"
      end
      assert event_fired
    end
  end

  test "#execute answers result with valid SQL" do
    result = @conn.execute "SELECT id, author_id, title FROM posts;"

    assert_equal %w[id author_id title], result.fields
  end

  test "#execute emits a query notification" do
    assert_notification("sql.active_record") do
      @conn.execute "SELECT * FROM posts;"
    end
  end

  test "#indexes answers indexes with existing indexes" do
    proof = [{
      table: "posts",
      name: "index_posts_on_author_id",
      unique: false,
      columns: ["author_id"],
      lengths: {},
      orders: {},
      opclasses: {},
      where: nil,
      type: nil,
      using: :btree,
      comment: nil
    }]

    indexes = @conn.indexes("posts").map do |index|
      {
        table: index.table,
        name: index.name,
        unique: index.unique,
        columns: index.columns,
        lengths: index.lengths,
        orders: index.orders,
        opclasses: index.opclasses,
        where: index.where,
        type: index.type,
        using: index.using,
        comment: index.comment
      }
    end

    assert_equal proof, indexes
  end

  test "#indexes answers empty array with no indexes" do
    assert_equal [], @conn.indexes("users")
  end

  test "#begin_db_transaction answers empty result" do
    result = @conn.begin_db_transaction
    assert_equal [], result.rows

    # rollback transaction so it doesn't bleed into other tests
    @conn.rollback_db_transaction
  end

  test "#begin_db_transaction raises error" do
    error = Class.new(Exception)
    assert_raises error do
      @conn.stub(:raw_execute, -> (*) { raise error }) do
        @conn.begin_db_transaction
      end
    end

    # rollback transaction so it doesn't bleed into other tests
    @conn.rollback_db_transaction
  end

  test "#commit_db_transaction answers empty result" do
    result = @conn.commit_db_transaction
    assert_equal [], result.rows
  end

  test "#commit_db_transaction raises error" do
    error = Class.new(Exception)
    assert_raises error do
      @conn.stub(:raw_execute, -> (*) { raise error }) do
        @conn.commit_db_transaction
      end
    end
  end

  test "#rollback_db_transaction raises error" do
    error = Class.new(Exception)
    assert_raises error do
      @conn.stub(:raw_execute, -> (*) { raise error }) do
        @conn.rollback_db_transaction
      end
    end
  end

  test "#select_value returns a single value" do
    assert_equal 123, @conn.select_value("SELECT 123")
  end

  test "#error_number answers number for exception" do
    exception = Minitest::Mock.new
    exception.expect :error_code, 123

    assert_equal 123, @conn.send(:error_number, exception)
  end

  test "read timeout raises ActiveRecord::AdapterTimeout" do
    db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")

    ActiveRecord::Base.establish_connection(
      db_config.configuration_hash.merge("read_timeout" => 1)
    )
    connection = ActiveRecord::Base.lease_connection

    error = assert_raises(ActiveRecord::AdapterTimeout) do
      connection.execute("SELECT SLEEP(2)")
    end
    assert_kind_of ActiveRecord::QueryAborted, error
    assert_equal Trilogy::TimeoutError, error.cause.class
    assert_equal connection.pool, error.connection_pool
  ensure
    ActiveRecord::Base.establish_connection :arunit
  end

  test "socket has precedence over host" do
    error = assert_raises ActiveRecord::ConnectionNotEstablished do
      ActiveRecord::ConnectionAdapters::TrilogyAdapter.new(host: "invalid", port: 12345, socket: "/var/invalid.sock").connect!
    end
    assert_includes error.message, "/var/invalid.sock"
  end

  test "EPIPE raises ActiveRecord::ConnectionFailed" do
    assert_raises(ActiveRecord::ConnectionFailed) do
      @conn.raw_connection.stub(:query, -> (*) { raise Trilogy::SyscallError::EPIPE }) do
        @conn.execute("SELECT 1")
      end
    end
  end

  test "ETIMEDOUT raises ActiveRecord::ConnectionFailed" do
    assert_raises(ActiveRecord::ConnectionFailed) do
      @conn.raw_connection.stub(:query, -> (*) { raise Trilogy::SyscallError::ETIMEDOUT }) do
        @conn.execute("SELECT 1")
      end
    end
  end

  test "ECONNREFUSED raises ActiveRecord::ConnectionFailed" do
    assert_raises(ActiveRecord::ConnectionFailed) do
      @conn.raw_connection.stub(:query, -> (*) { raise Trilogy::SyscallError::ECONNREFUSED }) do
        @conn.execute("SELECT 1")
      end
    end
  end

  test "ECONNRESET raises ActiveRecord::ConnectionFailed" do
    assert_raises(ActiveRecord::ConnectionFailed) do
      @conn.raw_connection.stub(:query, -> (*) { raise Trilogy::SyscallError::ECONNRESET }) do
        @conn.execute("SELECT 1")
      end
    end
  end

  test "setting prepared_statements to true raises" do
    assert_raises ArgumentError do
      ActiveRecord::ConnectionAdapters::TrilogyAdapter.new(prepared_statements: true).connect!
    end
  end
end
