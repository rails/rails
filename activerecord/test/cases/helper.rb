# frozen_string_literal: true

require "config"

require "stringio"

require "active_record"
require "cases/test_case"
require "active_support/dependencies"
require "active_support/logger"
require "active_support/core_ext/kernel/reporting"
require "active_support/core_ext/kernel/singleton_class"

require "support/config"
require "support/connection"

# TODO: Move all these random hacks into the ARTest namespace and into the support/ dir

Thread.abort_on_exception = true

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveRecord.deprecator.debug = true

# Disable available locale checks to avoid warnings running the test suite.
I18n.enforce_available_locales = false

# Connect to the database
ARTest.connect

# Quote "type" if it's a reserved word for the current connection.
QUOTED_TYPE = ActiveRecord::Base.connection.quote_column_name("type")

ActiveRecord.raise_on_assign_to_attr_readonly = true
ActiveRecord.belongs_to_required_validates_foreign_key = false

def current_adapter?(*types)
  types.any? do |type|
    ActiveRecord::ConnectionAdapters.const_defined?(type) &&
      ActiveRecord::Base.connection.is_a?(ActiveRecord::ConnectionAdapters.const_get(type))
  end
end

def in_memory_db?
  current_adapter?(:SQLite3Adapter) &&
  ActiveRecord::Base.connection_pool.db_config.database == ":memory:"
end

def mysql_enforcing_gtid_consistency?
  current_adapter?(:Mysql2Adapter) && "ON" == ActiveRecord::Base.connection.show_variable("enforce_gtid_consistency")
end

def supports_default_expression?
  if current_adapter?(:PostgreSQLAdapter)
    true
  elsif current_adapter?(:Mysql2Adapter)
    conn = ActiveRecord::Base.connection
    !conn.mariadb? && conn.database_version >= "8.0.13"
  end
end

def supports_non_unique_constraint_name?
  if current_adapter?(:Mysql2Adapter)
    conn = ActiveRecord::Base.connection
    conn.mariadb?
  else
    false
  end
end

def supports_text_column_with_default?
  if current_adapter?(:Mysql2Adapter)
    conn = ActiveRecord::Base.connection
    conn.mariadb? && conn.database_version >= "10.2.1"
  else
    true
  end
end

%w[
  supports_savepoints?
  supports_partial_index?
  supports_partitioned_indexes?
  supports_expression_index?
  supports_insert_returning?
  supports_insert_on_duplicate_skip?
  supports_insert_on_duplicate_update?
  supports_insert_conflict_target?
  supports_optimizer_hints?
  supports_datetime_with_precision?
].each do |method_name|
  define_method method_name do
    ActiveRecord::Base.connection.public_send(method_name)
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

  ActiveRecord::FixtureSet.reset_cache
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

# Encryption

ActiveRecord::Encryption.configure \
  primary_key: "test master key",
  deterministic_key: "test deterministic key",
  key_derivation_salt: "testing key derivation salt"

ActiveRecord::Encryption::ExtendedDeterministicQueries.install_support
ActiveRecord::Encryption::ExtendedDeterministicUniquenessValidator.install_support
