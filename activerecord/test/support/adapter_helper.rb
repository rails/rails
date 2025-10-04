# frozen_string_literal: true

module AdapterHelper
  def current_adapter?(*types)
    types.any? do |type|
      ActiveRecord::ConnectionAdapters.const_defined?(type) &&
        ActiveRecord::Base.connection_pool.db_config.adapter_class <= ActiveRecord::ConnectionAdapters.const_get(type)
    end
  end

  def in_memory_db?
    current_adapter?(:SQLite3Adapter) && ActiveRecord::Base.connection_pool.db_config.database == ":memory:"
  end

  def sqlite3_adapter_strict_strings_disabled?
    current_adapter?(:SQLite3Adapter) && !ActiveRecord::Base.connection_pool.db_config.configuration_hash[:strict]
  end

  def mysql_enforcing_gtid_consistency?
    current_adapter?(:Mysql2Adapter, :TrilogyAdapter) && "ON" == ActiveRecord::Base.lease_connection.show_variable("enforce_gtid_consistency")
  end

  def supports_default_expression?
    if current_adapter?(:PostgreSQLAdapter)
      true
    elsif current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
      conn = ActiveRecord::Base.lease_connection
      (conn.mariadb? && conn.database_version >= "10.2.1") ||
        (!conn.mariadb? && conn.database_version >= "8.0.13")
    end
  end

  def supports_non_unique_constraint_name?
    if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
      conn = ActiveRecord::Base.lease_connection
      conn.mariadb?
    else
      false
    end
  end

  def supports_text_column_with_default?
    if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
      conn = ActiveRecord::Base.lease_connection
      conn.mariadb? && conn.database_version >= "10.2.1"
    else
      true
    end
  end

  def supports_sql_standard_drop_constraint?
    if current_adapter?(:SQLite3Adapter)
      false
    elsif current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
      conn = ActiveRecord::Base.lease_connection
      if conn.mariadb?
        conn.database_version >= "10.3.13"
      else
        conn.database_version >= "8.0.19"
      end
    else
      true
    end
  end

  %w[
    supports_savepoints?
    supports_partial_index?
    supports_partitioned_indexes?
    supports_expression_index?
    supports_index_include?
    supports_insert_returning?
    supports_insert_on_duplicate_skip?
    supports_insert_on_duplicate_update?
    supports_insert_conflict_target?
    supports_optimizer_hints?
    supports_datetime_with_precision?
    supports_nulls_not_distinct?
    supports_identity_columns?
    supports_virtual_columns?
    supports_native_partitioning?
  ].each do |method_name|
    define_method method_name do
      ActiveRecord::Base.lease_connection.public_send(method_name)
    end
  end

  def enable_extension!(extension, connection)
    return false unless connection.supports_extensions?
    return connection.reconnect! if connection.extension_enabled?(extension)

    connection.enable_extension extension
    connection.commit_db_transaction if connection.transaction_open?
    connection.reconnect!
  end

  def disable_extension!(extension, connection)
    return false unless connection.supports_extensions?
    return true unless connection.extension_enabled?(extension)

    connection.disable_extension(extension, force: :cascade)
    connection.reconnect!
  end

  # Detects whether the server side of the connection physically has a
  # transaction open, independently of the adapter's opinion. Skips if we don't
  # know how to detect this.
  def raw_transaction_open?(connection)
    if current_adapter?(:PostgreSQLAdapter)
      connection.instance_variable_get(:@raw_connection).transaction_status == ::PG::PQTRANS_INTRANS
    elsif current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
      begin
        connection.instance_variable_get(:@raw_connection).query("SAVEPOINT transaction_test")
        connection.instance_variable_get(:@raw_connection).query("RELEASE SAVEPOINT transaction_test")

        true
      rescue
        false
      end
    elsif current_adapter?(:SQLite3Adapter)
      begin
        connection.instance_variable_get(:@raw_connection).transaction { nil }
        false
      rescue
        true
      end
    else
      skip("raw_transaction_open? unsupported")
    end
  end

  # Arrange for the server to disconnect the connection, leaving it broken (by
  # setting, and then sleeping to exceed, a very short timeout). Skips if we
  # can't do so.
  def remote_disconnect(connection)
    if current_adapter?(:PostgreSQLAdapter)
      # Connection was left in a bad state, need to reconnect to simulate fresh disconnect
      connection.verify! if connection.instance_variable_get(:@raw_connection).status == ::PG::CONNECTION_BAD
      unless connection.instance_variable_get(:@raw_connection).transaction_status == ::PG::PQTRANS_INTRANS
        connection.instance_variable_get(:@raw_connection).async_exec("begin")
      end
      connection.instance_variable_get(:@raw_connection).async_exec("set idle_in_transaction_session_timeout = '10ms'")
      sleep 0.05
    elsif current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
      connection.send(:internal_execute, "set @@wait_timeout=1", materialize_transactions: false)
      sleep 1.2
    else
      skip("remote_disconnect unsupported")
    end
  end

  def connection_id_from_server(connection)
    case connection.adapter_name
    when "Mysql2", "Trilogy"
      connection.execute("SELECT CONNECTION_ID()").to_a[0][0]
    when "PostgreSQL"
      connection.execute("SELECT pg_backend_pid()").to_a[0]["pg_backend_pid"]
    else
      skip("connection_id_from_server unsupported")
    end
  end

  # Uses a separate connection to admin-kill the connection with the given ID
  # from the server side. Skips if we can't do so.
  def kill_connection_from_server(connection_id, pool = ActiveRecord::Base.connection_pool)
    actor_connection = pool.checkout
    pool.remove(actor_connection)

    case actor_connection.adapter_name
    when "Mysql2", "Trilogy"
      actor_connection.execute("KILL #{connection_id}")
    when "PostgreSQL"
      actor_connection.execute("SELECT pg_terminate_backend(#{connection_id})")
    else
      skip("kill_connection_from_server unsupported")
    end

    actor_connection.close
  end
end
