# frozen_string_literal: true

require "active_support/logger"
require "models/college"
require "models/course"
require "models/professor"
require "models/other_dog"

module ARTest
  def self.connection_name
    ENV["ARCONN"] || config["default_connection"]
  end

  def self.test_configuration_hashes
    config.fetch("connections").fetch(connection_name) do
      puts "Connection #{connection_name.inspect} not found. Available connections: #{config['connections'].keys.join(', ')}"
      exit 1
    end
  end

  def self.connect
    ActiveRecord.async_query_executor = :global_thread_pool
    puts "Using #{connection_name}"
    ActiveRecord::Base.logger = ActiveSupport::Logger.new("debug.log", 1, 100 * 1024 * 1024)
    ActiveRecord::Base.configurations = test_configuration_hashes
    ActiveRecord::Base.establish_connection :arunit
    ARUnit2Model.establish_connection :arunit2

    arunit_adapter = ActiveRecord::Base.connection.pool.db_config.adapter

    if connection_name != arunit_adapter
      return if connection_name == "sqlite3_mem" && arunit_adapter == "sqlite3"
      raise ArgumentError, "The connection name did not match the adapter name. Connection name is '#{connection_name}' and the adapter name is '#{arunit_adapter}'."
    end
  end
end
