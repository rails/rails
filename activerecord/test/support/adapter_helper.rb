# frozen_string_literal: true

module AdapterHelper
  def current_adapter?(*types)
    types.any? do |type|
      ActiveRecord::ConnectionAdapters.const_defined?(type) &&
        ActiveRecord::Base.lease_connection.is_a?(ActiveRecord::ConnectionAdapters.const_get(type))
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
end
