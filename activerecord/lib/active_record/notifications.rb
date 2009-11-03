require 'active_support/notifications'

ActiveSupport::Notifications.subscribe("sql") do |event|
  ActiveRecord::Base.connection.log_info(event.payload[:sql], event.payload[:name], event.duration)
end
