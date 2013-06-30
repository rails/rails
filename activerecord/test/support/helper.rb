module ARTest
  Thread.abort_on_exception = true

  # Show backtraces for deprecated behavior for quicker cleanup.
  ActiveSupport::Deprecation.debug = true

  # Connect to the database
  connect

  class << self
    def current_adapter?(*types)
      types.any? do |type|
        ActiveRecord::ConnectionAdapters.const_defined?(type) &&
          ActiveRecord::Base.connection.is_a?(ActiveRecord::ConnectionAdapters.const_get(type))
      end
    end

    def in_memory_db?
      current_adapter?(:SQLite3Adapter) &&
      ActiveRecord::Base.connection_pool.spec.config[:database] == ":memory:"
    end

    def supports_savepoints?
      ActiveRecord::Base.connection.supports_savepoints?
    end

    def with_env_tz(new_tz = 'US/Eastern')
      old_tz, ENV['TZ'] = ENV['TZ'], new_tz
      yield
    ensure
      old_tz ? ENV['TZ'] = old_tz : ENV.delete('TZ')
    end

    def with_active_record_default_timezone(zone)
      old_zone, ActiveRecord::Base.default_timezone = ActiveRecord::Base.default_timezone, zone
      yield
    ensure
      ActiveRecord::Base.default_timezone = old_zone
    end
  end
end
