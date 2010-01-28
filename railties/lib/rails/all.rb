require "rails"

%w(
  active_support
  active_model
  active_record
  action_controller
  action_view
  action_mailer
  active_resource
  rails/test_unit
).each do |framework|
  begin
    require "#{framework}/railtie"
  rescue LoadError
  end
end