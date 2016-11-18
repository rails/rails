require "config"

require "stringio"

require "active_record"
require "cases/test_case"
require "active_support/dependencies"
require "active_support/logger"
require "active_support/core_ext/string/strip"

require "support/config"
require "support/connection"

# TODO: Move all these random hacks into the ARTest namespace and into the support/ dir

Thread.abort_on_exception = true

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

# Disable available locale checks to avoid warnings running the test suite.
I18n.enforce_available_locales = false

# Connect to the database
ARTest.connect

# Quote "type" if it's a reserved word for the current connection.
QUOTED_TYPE = ActiveRecord::Base.connection.quote_column_name("type")

# FIXME: Remove this when the deprecation cycle on TZ aware types by default ends.
ActiveRecord::Base.time_zone_aware_types << :time

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

def subsecond_precision_supported?
  ActiveRecord::Base.connection.supports_datetime_with_precision?
end

def mysql_enforcing_gtid_consistency?
  current_adapter?(:Mysql2Adapter) && "ON" == ActiveRecord::Base.connection.show_variable("enforce_gtid_consistency")
end

def supports_savepoints?
  ActiveRecord::Base.connection.supports_savepoints?
end

def with_env_tz(new_tz = "US/Eastern")
  old_tz, ENV["TZ"] = ENV["TZ"], new_tz
  yield
ensure
  old_tz ? ENV["TZ"] = old_tz : ENV.delete("TZ")
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

  connection.disable_extension extension
  connection.reconnect!
end

def load_schema
  # silence verbose schema loading
  original_stdout = $stdout
  $stdout = StringIO.new

  adapter_name = ActiveRecord::Base.connection.adapter_name.downcase
  adapter_specific_schema_file = SCHEMA_ROOT + "/#{adapter_name}_specific_schema.rb"

  load SCHEMA_ROOT + "/schema.rb"

  if File.exist?(adapter_specific_schema_file)
    load adapter_specific_schema_file
  end
ensure
  $stdout = original_stdout
end

load_schema

class SQLSubscriber
  attr_reader :logged
  attr_reader :payloads

  def initialize
    @logged = []
    @payloads = []
  end

  def start(name, id, payload)
    @payloads << payload
    @logged << [payload[:sql].squish, payload[:name], payload[:binds]]
  end

  def finish(name, id, payload); end
end

module InTimeZone
  private

    def in_time_zone(zone)
      old_zone  = Time.zone
      old_tz    = ActiveRecord::Base.time_zone_aware_attributes

      Time.zone = zone ? ActiveSupport::TimeZone[zone] : nil
      ActiveRecord::Base.time_zone_aware_attributes = !zone.nil?
      yield
    ensure
      Time.zone = old_zone
      ActiveRecord::Base.time_zone_aware_attributes = old_tz
    end
end

require "mocha/setup" # FIXME: stop using mocha
