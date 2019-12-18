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
    puts "Using #{connection_name}"
    ActiveRecord::Base.logger = ActiveSupport::Logger.new("debug.log", 0, 100 * 1024 * 1024)
    ActiveRecord::Base.connection_handlers = { ActiveRecord::Base.writing_role => ActiveRecord::Base.default_connection_handler }
    ActiveRecord::Base.configurations = test_configuration_hashes
    ActiveRecord::Base.establish_connection :arunit
    ARUnit2Model.establish_connection :arunit2
  end
end
