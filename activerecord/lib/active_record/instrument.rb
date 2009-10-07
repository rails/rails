require 'active_support/orchestra'

ActiveSupport::Orchestra.subscribe("sql") do |event|
  ActiveRecord::Base.connection.log_info(event.payload[:sql], event.payload[:name], event.duration)
end
