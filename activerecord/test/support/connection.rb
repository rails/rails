require 'logger'
require_dependency 'models/course'

module ARTest
  def self.connection_name
    ENV['ARCONN'] || config['default_connection']
  end

  def self.connection_config
    config['connections'][connection_name]
  end

  def self.connect
    puts "Using #{connection_name} with Identity Map #{ActiveRecord::IdentityMap.enabled? ? 'on' : 'off'}"
    ActiveRecord::Base.logger = Logger.new("debug.log")
    ActiveRecord::Base.configurations = connection_config
    ActiveRecord::Base.establish_connection 'arunit'
    Course.establish_connection 'arunit2'
  end
end
