# frozen_string_literal: true

require "cases/helper"
require "support/ddl_helper"
require "models/book"
require "models/post"

require "active_support/error_reporter/test_helper"

class TrilogyAdapterTest < ActiveRecord::TrilogyTestCase
  setup do
    @configuration = {
      adapter: "trilogy",
      username: "rails",
      database: "activerecord_unittest",
    }

    @adapter = trilogy_adapter
    @adapter.execute("TRUNCATE books")
    @adapter.execute("TRUNCATE posts")

    db_config = ActiveRecord::DatabaseConfigurations.new({}).resolve(@configuration)
    pool_config = ActiveRecord::ConnectionAdapters::PoolConfig.new(ActiveRecord::Base, db_config, :writing, :default)
    @pool = ActiveRecord::ConnectionAdapters::ConnectionPool.new(pool_config)
  end

  teardown do
    @adapter.disconnect!
  end

  test "#explain for one query" do
    explain = @adapter.explain("select * from posts")
    assert_match %(possible_keys), explain
  end

  test "#default_prepared_statements" do
    assert_not_predicate @pool.connection, :prepared_statements?
  end

  test "#adapter_name answers name" do
    assert_equal "Trilogy", @adapter.adapter_name
  end

  test "#supports_json answers true without Maria DB and greater version" do
    assert @adapter.supports_json?
  end

  test "#supports_json answers false without Maria DB and lesser version" do
    database_version = @adapter.class::Version.new("5.0.0", nil)

    @adapter.stub(:database_version, database_version) do
      assert_equal false, @adapter.supports_json?
    end
  end

  test "#supports_json answers false with Maria DB" do
    @adapter.stub(:mariadb?, true) do
      assert_equal false, @adapter.supports_json?
    end
  end

  test "#supports_comments? answers true" do
    assert @adapter.supports_comments?
  end

  test "#supports_comments_in_create? answers true" do
    assert @adapter.supports_comments_in_create?
  end

  test "#supports_savepoints? answers true" do
    assert @adapter.supports_savepoints?
  end

  test "#requires_reloading? answers false" do
    assert_equal false, @adapter.requires_reloading?
  end

  test "#native_database_types answers known types" do
    assert_equal ActiveRecord::ConnectionAdapters::TrilogyAdapter::NATIVE_DATABASE_TYPES, @adapter.native_database_types
  end

  test "#quote_column_name answers quoted string when not quoted" do
    assert_equal "`test`", @adapter.quote_column_name("test")
  end

  test "#quote_column_name answers triple quoted string when quoted" do
    assert_equal "```test```", @adapter.quote_column_name("`test`")
  end

  test "#quote_column_name answers quoted string for integer" do
    assert_equal "`1`", @adapter.quote_column_name(1)
  end

  test "#quote_string answers string with connection" do
    assert_equal "\\\"test\\\"", @adapter.quote_string(%("test"))
  end

  test "#quote_string works when the connection is known to be closed" do
    adapter = trilogy_adapter
    adapter.connect!
    adapter.instance_variable_get(:@raw_connection).close

    assert_equal "\\\"test\\\"", adapter.quote_string(%("test"))
  end

  test "#quoted_true answers TRUE" do
    assert_equal "TRUE", @adapter.quoted_true
  end

  test "#quoted_false answers FALSE" do
    assert_equal "FALSE", @adapter.quoted_false
  end

  test "#active? answers true with connection" do
    assert @adapter.active?
  end

  test "#active? answers false with connection and exception" do
    @adapter.send(:connection).stub(:ping, -> { raise ::Trilogy::BaseError.new }) do
      assert_equal false, @adapter.active?
    end
  end

  test "#active? answers false without connection" do
    adapter = trilogy_adapter
    assert_equal false, adapter.active?
  end

  test "#reconnect closes connection with connection" do
    connection = Minitest::Mock.new Trilogy.new(@configuration)
    connection.expect :close, true
    adapter = trilogy_adapter_with_connection(connection)
    adapter.reconnect!

    assert connection.verify
  end

  test "#reconnect doesn't retain old connection on failure" do
    old_connection = Minitest::Mock.new Trilogy.new(@configuration)
    old_connection.expect :close, true

    adapter = trilogy_adapter_with_connection(old_connection)

    begin
      Trilogy.stub(:new, -> _ { raise Trilogy::BaseError.new }) do
        adapter.reconnect!
      end
    rescue ActiveRecord::StatementInvalid => ex
      assert_instance_of Trilogy::BaseError, ex.cause
    else
      flunk "Expected Trilogy::BaseError to be raised"
    end

    assert_nil adapter.send(:connection)
  end

  test "#reconnect answers new connection with existing connection" do
    old_connection = @adapter.send(:connection)
    @adapter.reconnect!
    connection = @adapter.send(:connection)

    assert_instance_of Trilogy, connection
    assert_not_equal old_connection, connection
  end

  test "#reconnect answers new connection without existing connection" do
    adapter = trilogy_adapter
    adapter.reconnect!
    assert_instance_of Trilogy, adapter.send(:connection)
  end

  test "#reset closes connection with existing connection" do
    connection = Minitest::Mock.new Trilogy.new(@configuration)
    connection.expect :close, true
    adapter = trilogy_adapter_with_connection(connection)
    adapter.reset!

    assert connection.verify
  end

  test "#reset answers new connection with existing connection" do
    old_connection = @adapter.send(:connection)
    @adapter.reset!
    connection = @adapter.send(:connection)

    assert_instance_of Trilogy, connection
    assert_not_equal old_connection, connection
  end

  test "#reset answers new connection without existing connection" do
    adapter = trilogy_adapter
    adapter.reset!
    assert_instance_of Trilogy, adapter.send(:connection)
  end

  test "#disconnect closes connection with existing connection" do
    connection = Minitest::Mock.new Trilogy.new(@configuration)
    connection.expect :close, true
    adapter = trilogy_adapter_with_connection(connection)
    adapter.disconnect!

    assert connection.verify
  end

  test "#disconnect makes adapter inactive with connection" do
    @adapter.disconnect!
    assert_equal false, @adapter.active?
  end

  test "#disconnect answers nil with connection" do
    assert_nil @adapter.disconnect!
  end

  test "#disconnect answers nil without connection" do
    adapter = trilogy_adapter
    assert_nil adapter.disconnect!
  end

  test "#disconnect leaves adapter inactive without connection" do
    adapter = trilogy_adapter
    adapter.disconnect!

    assert_equal false, adapter.active?
  end

  test "#discard answers nil with connection" do
    assert_nil @adapter.discard!
  end

  test "#discard makes adapter inactive with connection" do
    @adapter.discard!
    assert_equal false, @adapter.active?
  end

  test "#discard answers nil without connection" do
    adapter = trilogy_adapter
    assert_nil adapter.discard!
  end

  test "#exec_query answers result with valid query" do
    result = @adapter.exec_query "SELECT id, author_id, title, body FROM posts;"

    assert_equal %w[id author_id title body], result.columns
    assert_equal [], result.rows
  end

  test "#exec_query fails with invalid query" do
    assert_raises_with_message ActiveRecord::StatementInvalid, /'activerecord_unittest.bogus' doesn't exist/ do
      @adapter.exec_query "SELECT * FROM bogus;"
    end
  end

  test "#exec_insert inserts new row" do
    @adapter.exec_insert "INSERT INTO posts (title, body) VALUES ('Test', 'example');", nil, nil
    result = @adapter.execute "SELECT id, title, body FROM posts;"

    assert_equal [[1, "Test", "example"]], result.rows
  end

  test "#exec_delete deletes existing row" do
    @adapter.execute "INSERT INTO posts (title, body) VALUES ('Test', 'example');"
    @adapter.exec_delete "DELETE FROM posts WHERE title = 'Test';", nil, nil
    result = @adapter.execute "SELECT id, title, body FROM posts;"

    assert_equal [], result.rows
  end

  test "#exec_update updates existing row" do
    @adapter.execute "INSERT INTO posts (title, body) VALUES ('Test', 'example');"
    @adapter.exec_update "UPDATE posts SET title = 'Test II' where body = 'example';", nil, nil
    result = @adapter.execute "SELECT id, title, body FROM posts;"

    assert_equal [[1, "Test II", "example"]], result.rows
  end

  test "default query flags set timezone to UTC" do
    if ActiveRecord.respond_to?(:default_timezone)
      assert_equal :utc, ActiveRecord.default_timezone
    else
      assert_equal :utc, ActiveRecord::Base.default_timezone
    end
    ruby_time = Time.utc(2019, 5, 31, 12, 52)
    time = "2019-05-31 12:52:00"

    @adapter.execute("INSERT into books (name, format, created_at, updated_at) VALUES ('name', 'paperback', '#{time}', '#{time}');")
    result = @adapter.execute("select * from books limit 1;")

    result.each_hash do |hsh|
      assert_equal ruby_time, hsh["created_at"]
      assert_equal ruby_time, hsh["updated_at"]
    end

    assert_equal 1, @adapter.send(:connection).query_flags
  end

  test "query flags for timezone can be set to local" do
    if ActiveRecord.respond_to?(:default_timezone)
      old_timezone, ActiveRecord.default_timezone = ActiveRecord.default_timezone, :local
      assert_equal :local, ActiveRecord.default_timezone
    else
      old_timezone, ActiveRecord::Base.default_timezone = ActiveRecord::Base.default_timezone, :local
      assert_equal :local, ActiveRecord::Base.default_timezone
    end
    ruby_time = Time.local(2019, 5, 31, 12, 52)
    time = "2019-05-31 12:52:00"

    @adapter.execute("INSERT into books (name, format, created_at, updated_at) VALUES ('name', 'paperback', '#{time}', '#{time}');")
    result = @adapter.execute("select * from books limit 1;")

    result.each_hash do |hsh|
      assert_equal ruby_time, hsh["created_at"]
      assert_equal ruby_time, hsh["updated_at"]
    end

    assert_equal 5, @adapter.send(:connection).query_flags
  ensure
    if ActiveRecord.respond_to?(:default_timezone)
      ActiveRecord.default_timezone = old_timezone
    else
      ActiveRecord::Base.default_timezone = old_timezone
    end
  end

  test "query flags for timezone can be set to local and reset to utc" do
    if ActiveRecord.respond_to?(:default_timezone)
      old_timezone, ActiveRecord.default_timezone = ActiveRecord.default_timezone, :local
      assert_equal :local, ActiveRecord.default_timezone
    else
      old_timezone, ActiveRecord::Base.default_timezone = ActiveRecord::Base.default_timezone, :local
      assert_equal :local, ActiveRecord::Base.default_timezone
    end
    ruby_time = Time.local(2019, 5, 31, 12, 52)
    time = "2019-05-31 12:52:00"

    @adapter.execute("INSERT into books (name, format, created_at, updated_at) VALUES ('name', 'paperback', '#{time}', '#{time}');")
    result = @adapter.execute("select * from books limit 1;")

    result.each_hash do |hsh|
      assert_equal ruby_time, hsh["created_at"]
      assert_equal ruby_time, hsh["updated_at"]
    end

    assert_equal 5, @adapter.send(:connection).query_flags

    if ActiveRecord.respond_to?(:default_timezone)
      ActiveRecord.default_timezone = :utc
    else
      ActiveRecord::Base.default_timezone = :utc
    end

    ruby_utc_time = Time.utc(2019, 5, 31, 12, 52)
    utc_result = @adapter.execute("select * from books limit 1;")

    utc_result.each_hash do |hsh|
      assert_equal ruby_utc_time, hsh["created_at"]
      assert_equal ruby_utc_time, hsh["updated_at"]
    end

    assert_equal 1, @adapter.send(:connection).query_flags
  ensure
    if ActiveRecord.respond_to?(:default_timezone)
      ActiveRecord.default_timezone = old_timezone
    else
      ActiveRecord::Base.default_timezone = old_timezone
    end
  end

  test "#execute answers results for valid query" do
    result = @adapter.execute "SELECT id, author_id, title, body FROM posts;"
    assert_equal %w[id author_id title body], result.fields
  end

  test "#execute answers results for valid query after reconnect" do
    mock_connection = Minitest::Mock.new Trilogy.new(@configuration)
    adapter = trilogy_adapter_with_connection(mock_connection)

    # Cause an ER_SERVER_SHUTDOWN error (code 1053) after the session is
    # set. On reconnect, the adapter will get a real, working connection.
    server_shutdown_error = Trilogy::ProtocolError.new
    server_shutdown_error.instance_variable_set(:@error_code, 1053)
    mock_connection.expect(:query, nil) { raise server_shutdown_error }

    assert_raises(ActiveRecord::ConnectionFailed) do
      adapter.execute "SELECT * FROM posts;"
    end

    adapter.reconnect!
    result = adapter.execute "SELECT id, author_id, title, body FROM posts;"

    assert_equal %w[id author_id title body], result.fields
    assert mock_connection.verify
    mock_connection.close
  end

  test "#execute fails with invalid query" do
    assert_raises_with_message ActiveRecord::StatementInvalid, /Table 'activerecord_unittest.bogus' doesn't exist/ do
      @adapter.execute "SELECT * FROM bogus;"
    end
  end

  test "#execute fails with invalid SQL" do
    assert_raises(ActiveRecord::StatementInvalid) do
      @adapter.execute "SELECT bogus FROM posts;"
    end
  end

  test "#execute answers results for valid query after losing connection unexpectedly" do
    connection = Trilogy.new(@configuration.merge(read_timeout: 1))

    adapter = trilogy_adapter_with_connection(connection)
    assert adapter.active?

    # Make connection lost for future queries by exceeding the read timeout
    assert_raises(Trilogy::TimeoutError) do
      connection.query "SELECT sleep(2);"
    end
    assert_not adapter.active?

    # The adapter believes the connection is verified, so it will run the
    # following query immediately. It will fail, and as the query's not
    # retryable, the adapter will raise an error.

    # The next query fails because the connection is lost
    assert_raises(ActiveRecord::ConnectionFailed) do
      adapter.execute "SELECT COUNT(*) FROM posts;"
    end
    assert_not adapter.active?

    # The adapter now knows the connection is lost, so it will re-verify (and
    # ultimately reconnect) before running another query.

    # This query triggers a reconnect
    result = adapter.execute "SELECT COUNT(*) FROM posts;"
    assert_equal [[0]], result.rows
    assert adapter.active?
  end

  test "#execute answers results for valid query after losing connection" do
    connection = Trilogy.new(@configuration.merge(read_timeout: 1))

    adapter = trilogy_adapter_with_connection(connection)
    assert adapter.active?

    # Make connection lost for future queries by exceeding the read timeout
    assert_raises(ActiveRecord::StatementInvalid) do
      adapter.execute "SELECT sleep(2);"
    end
    assert_not adapter.active?

    # The above failure has not yet caused a reconnect, but the adapter has
    # lost confidence in the connection, so it will re-verify before running
    # the next query -- which means it will succeed.

    # This query triggers a reconnect
    result = adapter.execute "SELECT COUNT(*) FROM posts;"
    assert_equal [[0]], result.rows
    assert adapter.active?
  end

  test "#execute fails if the connection is closed" do
    connection = ::Trilogy.new(@configuration.merge(read_timeout: 1))

    adapter = trilogy_adapter_with_connection(connection)
    adapter.pool = @pool

    assert_raises ActiveRecord::ConnectionFailed do
      adapter.transaction do
        # Make connection lost for future queries by exceeding the read timeout
        assert_raises(ActiveRecord::StatementInvalid) do
          adapter.execute "SELECT sleep(2);"
        end
        assert_not adapter.active?

        adapter.execute "SELECT COUNT(*) FROM posts;"
      end
    end

    assert_not adapter.active?

    # This query triggers a reconnect
    result = adapter.execute "SELECT COUNT(*) FROM posts;"
    assert_equal [[0]], result.rows
  end

  test "can reconnect after failing to rollback" do
    connection = ::Trilogy.new(@configuration.merge(read_timeout: 1))

    adapter = trilogy_adapter_with_connection(connection)
    adapter.pool = @pool

    adapter.transaction do
      adapter.execute("SELECT 1")

      # Cause the client to disconnect without the adapter's awareness
      assert_raises ::Trilogy::TimeoutError do
        adapter.send(:connection).query("SELECT sleep(2)")
      end

      raise ActiveRecord::Rollback
    end

    result = adapter.execute("SELECT 1")
    assert_equal [[1]], result.rows
  end

  test "can reconnect after failing to commit" do
    connection = Trilogy.new(@configuration.merge(read_timeout: 1))

    adapter = trilogy_adapter_with_connection(connection)
    adapter.pool = @pool

    assert_raises ActiveRecord::ConnectionFailed do
      adapter.transaction do
        adapter.execute("SELECT 1")

        # Cause the client to disconnect without the adapter's awareness
        assert_raises Trilogy::TimeoutError do
          adapter.send(:connection).query("SELECT sleep(2)")
        end
      end
    end

    result = adapter.execute("SELECT 1")
    assert_equal [[1]], result.rows
  end

  test "#execute fails with deadlock error" do
    adapter = trilogy_adapter

    new_connection = Trilogy.new(@configuration)

    deadlocking_adapter = trilogy_adapter_with_connection(new_connection)

    # Add seed data
    adapter.insert("INSERT INTO posts (title, body) VALUES('Setup', 'Content')")

    adapter.transaction do
      adapter.execute(
        "UPDATE posts SET title = 'Connection 1' WHERE title != 'Connection 1';"
      )

      # Decrease the lock wait timeout in this session
      deadlocking_adapter.execute("SET innodb_lock_wait_timeout = 1")

      assert_raises(ActiveRecord::LockWaitTimeout) do
        deadlocking_adapter.execute(
          "UPDATE posts SET title = 'Connection 2' WHERE title != 'Connection 2';"
        )
      end
    end
  end

  test "#execute fails with unknown error" do
    assert_raises_with_message(ActiveRecord::StatementInvalid, /A random error/) do
      connection = Minitest::Mock.new Trilogy.new(@configuration)
      connection.expect(:query, nil) { raise Trilogy::ProtocolError, "A random error." }
      adapter = trilogy_adapter_with_connection(connection)

      adapter.execute "SELECT * FROM posts;"
    end
  end

  test "#select_all when query cache is enabled fires the same notification payload for uncached and cached queries" do
    @adapter.cache do
      event_fired = false
      subscription = ->(name, start, finish, id, payload) {
        event_fired = true

        # First, we test keys that are defined by default by the AbstractAdapter
        assert_includes payload, :sql
        assert_equal "SELECT * FROM posts", payload[:sql]

        assert_includes payload, :name
        assert_equal "uncached query", payload[:name]

        assert_includes payload, :connection
        assert_equal @adapter, payload[:connection]

        assert_includes payload, :binds
        assert_equal [], payload[:binds]

        assert_includes payload, :type_casted_binds
        assert_equal [], payload[:type_casted_binds]

        # :stament_name is always nil and never set 🤷‍♂️
        assert_includes payload, :statement_name
        assert_nil payload[:statement_name]

        assert_not_includes payload, :cached
      }
      ActiveSupport::Notifications.subscribed(subscription, "sql.active_record") do
        @adapter.select_all "SELECT * FROM posts", "uncached query"
      end
      assert event_fired

      event_fired = false
      subscription = ->(name, start, finish, id, payload) {
        event_fired = true

        # First, we test keys that are defined by default by the AbstractAdapter
        assert_includes payload, :sql
        assert_equal "SELECT * FROM posts", payload[:sql]

        assert_includes payload, :name
        assert_equal "cached query", payload[:name]

        assert_includes payload, :connection
        assert_equal @adapter, payload[:connection]

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
        @adapter.select_all "SELECT * FROM posts", "cached query"
      end
      assert event_fired
    end
  end

  test "#execute answers result with valid SQL" do
    result = @adapter.execute "SELECT id, author_id, title FROM posts;"

    assert_equal %w[id author_id title], result.fields
    assert_equal [], result.rows
  end

  test "#execute emits a query notification" do
    assert_notification("sql.active_record") do
      @adapter.execute "SELECT * FROM posts;"
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

    indexes = @adapter.indexes("posts").map do |index|
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
    assert_equal [], @adapter.indexes("users")
  end

  test "#begin_db_transaction answers empty result" do
    result = @adapter.begin_db_transaction
    assert_equal [], result.rows

    # rollback transaction so it doesn't bleed into other tests
    @adapter.rollback_db_transaction
  end

  test "#begin_db_transaction raises error" do
    error = Class.new(Exception)
    assert_raises error do
      @adapter.stub(:raw_execute, -> (*) { raise error }) do
        @adapter.begin_db_transaction
      end
    end

    # rollback transaction so it doesn't bleed into other tests
    @adapter.rollback_db_transaction
  end

  test "#commit_db_transaction answers empty result" do
    result = @adapter.commit_db_transaction
    assert_equal [], result.rows
  end

  test "#commit_db_transaction raises error" do
    error = Class.new(Exception)
    assert_raises error do
      @adapter.stub(:raw_execute, -> (*) { raise error }) do
        @adapter.commit_db_transaction
      end
    end
  end

  test "#rollback_db_transaction raises error" do
    error = Class.new(Exception)
    assert_raises error do
      @adapter.stub(:raw_execute, -> (*) { raise error }) do
        @adapter.rollback_db_transaction
      end
    end
  end

  test "#insert answers ID with ID" do
    assert_equal 5, @adapter.insert("INSERT INTO posts (title, body) VALUES ('test', 'content');", "test", nil, 5)
  end

  test "#insert answers last ID without ID" do
    assert_equal 1, @adapter.insert("INSERT INTO posts (title, body) VALUES ('test', 'content');", "test")
  end

  test "#insert answers incremented last ID without ID" do
    @adapter.insert("INSERT INTO posts (title, body) VALUES ('test', 'content');", "test")
    assert_equal 2, @adapter.insert("INSERT INTO posts (title, body) VALUES ('test', 'content');", "test")
  end

  test "#update answers affected row count when updatable" do
    @adapter.insert("INSERT INTO posts (title, body) VALUES ('test', 'content');")
    assert_equal 1, @adapter.update("UPDATE posts SET title = 'Test' WHERE id = 1;")
  end

  test "#update answers zero affected rows when not updatable" do
    assert_equal 0, @adapter.update("UPDATE posts SET title = 'Test' WHERE id = 1;")
  end

  test "strict mode can be disabled" do
    adapter = trilogy_adapter(strict: false)

    adapter.execute "INSERT INTO posts (title) VALUES ('test');"
    result = adapter.execute "SELECT * FROM posts;"
    assert_equal [[1, nil, "test", "", nil, 0, 0, 0, 0, 0, 0, 0]], result.rows
  end

  test "#select_value returns a single value" do
    assert_equal 123, @adapter.select_value("SELECT 123")
  end

  test "#each_hash yields symbolized result rows" do
    @adapter.execute "INSERT INTO posts (title, body) VALUES ('test', 'content');"
    result = @adapter.execute "SELECT title, body FROM posts;"

    @adapter.each_hash(result) do |row|
      assert_equal "test", row[:title]
    end
  end

  test "#each_hash returns an enumarator of symbolized result rows when no block is given" do
    @adapter.execute "INSERT INTO posts (title, body) VALUES ('test', 'content');"
    result = @adapter.execute "SELECT * FROM posts;"
    rows_enum = @adapter.each_hash result

    assert_equal "test", rows_enum.next[:title]
  end

  test "#each_hash returns empty array when results is empty" do
    result = @adapter.execute "SELECT * FROM posts;"
    rows = @adapter.each_hash result

    assert_empty rows.to_a
  end

  test "#error_number answers number for exception" do
    exception = Minitest::Mock.new
    exception.expect :error_code, 123

    assert_equal 123, @adapter.error_number(exception)
  end

  # We only want to test if QueryLogs functionality is available
  if ActiveRecord.respond_to?(:query_transformers)
    test "execute uses AbstractAdapter#transform_query when available" do
      # Add custom query transformer
      old_query_transformers = ActiveRecord.query_transformers
      ActiveRecord.query_transformers = [-> (sql, _adapter) { sql + " /* it works */" }]

      sql = "SELECT * FROM posts;"

      mock_connection = Minitest::Mock.new Trilogy.new(@configuration)
      adapter = trilogy_adapter_with_connection(mock_connection)
      mock_connection.expect :query, nil, [sql + " /* it works */"]

      adapter.execute sql

      assert mock_connection.verify
    ensure
      # Teardown custom query transformers
      ActiveRecord.query_transformers = old_query_transformers
    end
  end

  test "parses ssl_mode as int" do
    adapter = trilogy_adapter(ssl_mode: 0)
    adapter.connect!

    assert adapter.active?
  end

  test "parses ssl_mode as string" do
    adapter = trilogy_adapter(ssl_mode: "disabled")
    adapter.connect!

    assert adapter.active?
  end

  test "parses ssl_mode as string prefixed" do
    adapter = trilogy_adapter(ssl_mode: "SSL_MODE_DISABLED")
    adapter.connect!

    assert adapter.active?
  end

  def trilogy_adapter_with_connection(connection, **config_overrides)
    ActiveRecord::ConnectionAdapters::TrilogyAdapter
      .new(connection, nil, {}, @configuration.merge(config_overrides))
      .tap { |conn| conn.execute("SELECT 1") }
  end

  def trilogy_adapter(**config_overrides)
    ActiveRecord::ConnectionAdapters::TrilogyAdapter
      .new(@configuration.merge(config_overrides))
  end

  def assert_raises_with_message(exception, message, &block)
    block.call
  rescue exception => error
    assert_match message, error.message
  else
    fail %(Expected #{exception} with message "#{message}" but nothing failed.)
  end

  # Create a temporary subscription to verify notification is sent.
  # Optionally verify the notification payload includes expected types.
  def assert_notification(notification, expected_payload = {}, &block)
    notification_sent = false

    subscription = lambda do |*args|
      notification_sent = true
      event = ActiveSupport::Notifications::Event.new(*args)

      expected_payload.each do |key, value|
        assert(
          value === event.payload[key],
          "Expected notification payload[:#{key}] to match #{value.inspect}, but got #{event.payload[key].inspect}."
        )
      end
    end

    ActiveSupport::Notifications.subscribed(subscription, notification) do
      block.call if block_given?
    end

    assert notification_sent, "#{notification} notification was not sent"
  end

  # Create a temporary subscription to verify notification was not sent.
  def assert_no_notification(notification, &block)
    notification_sent = false

    subscription = lambda do |*args|
      notification_sent = true
    end

    ActiveSupport::Notifications.subscribed(subscription, notification) do
      block.call if block_given?
    end

    assert_not notification_sent, "#{notification} notification was sent"
  end
end
