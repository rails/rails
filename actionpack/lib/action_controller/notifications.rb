require 'active_support/notifications'

ActiveSupport::Notifications.subscribe(/(read|write|cache|expire|exist)_(fragment|page)\??/) do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)

  if logger = ActionController::Base.logger
    human_name = event.name.to_s.humanize
    logger.info("#{human_name} (%.1fms)" % event.duration)
  end
end
