require 'active_support/orchestra'

ActiveSupport::Orchestra.subscribe(/(read|write|cache|expire|exist)_(fragment|page)\??/) do |event|
  if logger = ActionController::Base.logger
    human_name = event.name.to_s.humanize
    logger.info("#{human_name} (%.1fms)" % event.duration)
  end
end
