require 'active_support/logger'
require 'models/college'
require 'models/course'

module ARTest
  def self.connection_name
    ENV['ARCONN'] || config['default_connection']
  end

  def self.connection_config
    config['connections'][connection_name]
  end

  def self.connect
    puts "Using #{connection_name}"
    ActiveRecord::Model.logger = ActiveSupport::Logger.new("debug.log")
    ActiveRecord::Model.configurations = connection_config
    ActiveRecord::Model.establish_connection 'arunit'
    ARUnit2Model.establish_connection 'arunit2'
  end
end
