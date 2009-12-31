require "rails/core"

%w(
  active_model
  active_record
  action_controller
  action_view
  action_mailer
  active_resource
).each do |framework|
  begin
    require "#{framework}/rails"
  rescue LoadError
  end
end