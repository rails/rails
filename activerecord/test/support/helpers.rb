module TestHelpers
  def current_adapter?(*types)
    types.any? do |type|
      ActiveRecord::ConnectionAdapters.const_defined?(type) &&
        ActiveRecord::Base.connection.is_a?(ActiveRecord::ConnectionAdapters.const_get(type))
    end
  end

  def disable_extension!(extension, connection)
    return false unless connection.supports_extensions?
    return true unless connection.extension_enabled?(extension)

    connection.disable_extension extension
    connection.reconnect!
  end

  def enable_extension!(extension, connection)
    return false unless connection.supports_extensions?
    return connection.reconnect! if connection.extension_enabled?(extension)

    connection.enable_extension extension
    connection.commit_db_transaction if connection.transaction_open?
    connection.reconnect!
  end

  def in_memory_db?
    current_adapter?(:SQLite3Adapter) &&
    ActiveRecord::Base.connection_pool.spec.config[:database] == ":memory:"
  end

  def mysql_enforcing_gtid_consistency?
    current_adapter?(:Mysql2Adapter) && 'ON' == ActiveRecord::Base.connection.show_variable('enforce_gtid_consistency')
  end

  def subsecond_precision_supported?
    ActiveRecord::Base.connection.supports_datetime_with_precision?
  end

  def supports_savepoints?
    ActiveRecord::Base.connection.supports_savepoints?
  end

  # This method makes sure that tests don't leak global state related to time zones.
  EXPECTED_ZONE = nil
  EXPECTED_DEFAULT_TIMEZONE = :utc
  EXPECTED_TIME_ZONE_AWARE_ATTRIBUTES = false

  def verify_default_timezone_config
    if Time.zone != EXPECTED_ZONE
      $stderr.puts <<-MSG
  \n#{self}
      Global state `Time.zone` was leaked.
        Expected: #{EXPECTED_ZONE}
        Got: #{Time.zone}
      MSG
    end
    if ActiveRecord::Base.default_timezone != EXPECTED_DEFAULT_TIMEZONE
      $stderr.puts <<-MSG
  \n#{self}
      Global state `ActiveRecord::Base.default_timezone` was leaked.
        Expected: #{EXPECTED_DEFAULT_TIMEZONE}
        Got: #{ActiveRecord::Base.default_timezone}
      MSG
    end
    if ActiveRecord::Base.time_zone_aware_attributes != EXPECTED_TIME_ZONE_AWARE_ATTRIBUTES
      $stderr.puts <<-MSG
  \n#{self}
      Global state `ActiveRecord::Base.time_zone_aware_attributes` was leaked.
        Expected: #{EXPECTED_TIME_ZONE_AWARE_ATTRIBUTES}
        Got: #{ActiveRecord::Base.time_zone_aware_attributes}
      MSG
    end
  end

  def with_env_tz(new_tz = 'US/Eastern')
    old_tz, ENV['TZ'] = ENV['TZ'], new_tz
    yield
  ensure
    old_tz ? ENV['TZ'] = old_tz : ENV.delete('TZ')
  end

  def with_timezone_config(cfg)
    verify_default_timezone_config

    old_default_zone = ActiveRecord::Base.default_timezone
    old_awareness = ActiveRecord::Base.time_zone_aware_attributes
    old_zone = Time.zone

    if cfg.has_key?(:default)
      ActiveRecord::Base.default_timezone = cfg[:default]
    end
    if cfg.has_key?(:aware_attributes)
      ActiveRecord::Base.time_zone_aware_attributes = cfg[:aware_attributes]
    end
    if cfg.has_key?(:zone)
      Time.zone = cfg[:zone]
    end
    yield
  ensure
    ActiveRecord::Base.default_timezone = old_default_zone
    ActiveRecord::Base.time_zone_aware_attributes = old_awareness
    Time.zone = old_zone
  end
end
