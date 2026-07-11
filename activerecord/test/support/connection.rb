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

  # Whether this test run is proxied though ractor connection handling or not.
  def self.ractor_proxy?
    connection_name.end_with?("_ractor")
  end

  def self.without_ractor_proxy
    handler_was = ActiveSupport::IsolatedExecutionState[:active_record_connection_handler]
    handler = ActiveRecord::Base.connection_handler
    if handler.is_a?(ActiveRecord::ConnectionAdapters::RactorConnectionHandler)
      ActiveRecord::Base.connection_handler = handler.main_ractor_handler
    end
    yield
  ensure
    ActiveRecord::Base.connection_handler = handler_was
  end

  def self.test_configuration_hashes
    config.fetch("connections").fetch(connection_name) do
      puts "Connection #{connection_name.inspect} not found. Available connections: #{config['connections'].keys.join(', ')}"
      exit 1
    end
  end

  # In a proxied run, every thread and worker Ractor must resolve to the
  # Ractor handler (a thread-local assignment would only cover the boot
  # thread), while `default_connection_handler` keeps owning the real pools.
  # Prepended to Base's singleton class, so Core.ractor_connection_handler's
  # main-Ractor guard is overridden without redefining it. A plain `def` in a
  # named module carries no closure, so worker Ractors may call it.
  module RactorProxy
    def ractor_connection_handler
      ActiveRecord::ConnectionAdapters::RactorConnectionHandler.instance
    end
  end

  def self.connect
    ActiveRecord.async_query_executor = :global_thread_pool
    ActiveRecord::Base.singleton_class.prepend(RactorProxy) if ractor_proxy?
    puts "Using #{connection_name}#{ " with prepared statements" if ENV["MYSQL_PREPARED_STATEMENTS"]}"

    if ENV["BUILDKITE"]
      ActiveRecord::Base.logger = nil
    else
      ActiveRecord::Base.logger = ActiveSupport::Logger.new("debug.log", 1, 100.megabytes)
    end

    ActiveRecord::Base.configurations = test_configuration_hashes
    ActiveRecord::Base.establish_connection :arunit
    ARUnit2Model.establish_connection :arunit2

    arunit_adapter = ActiveRecord::Base.lease_connection.pool.db_config.adapter

    unless connection_name.include?(arunit_adapter)
      raise ArgumentError, "The connection name did not match the adapter name. Connection name is '#{connection_name}' and the adapter name is '#{arunit_adapter}'."
    end
  end
end
