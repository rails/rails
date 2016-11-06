require "rails"

%w(
  active_record/railtie
  action_controller/railtie
  action_view/railtie
  action_mailer/railtie
  active_job/railtie
  action_cable/engine
  rails/test_unit/railtie
  sprockets/railtie
  action_system_test/railtie
).each do |railtie|
  begin
    require railtie
  rescue LoadError
  end
end
