require 'active_support/notifications'

ActiveSupport::Notifications.subscribe("sql") do |name, before, after, result, instrumenter_id, payload|
  ActiveRecord::Base.connection.log_info(payload[:sql], name, after - before)
end
