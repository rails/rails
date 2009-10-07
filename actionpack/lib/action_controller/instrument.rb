require 'active_support/orchestra'

ActiveSupport::Orchestra.subscribe(/(read|write|cache|expire|exist)_(fragment|page)\??/) do |event|
  human_name = event.name.to_s.humanize
  ActionController::Base.log("#{human_name} (%.1fms)" % event.duration)
end
