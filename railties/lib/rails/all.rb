require "rails"

%w(
  active_model
  active_record
  action_controller
  action_view
  action_mailer
  active_resource
).each do |framework|
  begin
    require "#{framework}/railtie"
  rescue LoadError
  end
end