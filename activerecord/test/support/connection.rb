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

  def self.connection_config
    config.fetch("connections").fetch(connection_name) do
      puts "Connection #{connection_name.inspect} not found. Available connections: #{config['connections'].keys.join(', ')}"
      exit 1
    end
  end

  def self.connect
    puts "Using #{connection_name}"
    ActiveRecord::Base.logger = ActiveSupport::Logger.new("debug.log", 0, 100 * 1024 * 1024)
    ActiveRecord::Base.configurations = connection_config
    ActiveRecord::Base.establish_connection :arunit
    ARUnit2Model.establish_connection :arunit2
  end
end
