require 'logger'
require_dependency 'models/course'

module ARTest
  def self.connect
    connection_name = ENV['ARCONN'] || config['default_connection']
    puts "Using #{connection_name}"
    ActiveRecord::Base.logger = Logger.new("debug.log")
    ActiveRecord::Base.configurations = config['connections'][connection_name]
    ActiveRecord::Base.establish_connection 'arunit'
    Course.establish_connection 'arunit2'
  end
end
