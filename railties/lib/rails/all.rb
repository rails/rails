require "rails"

if defined?(Rake) && Rake.application.top_level_tasks.grep(/^test(?::|$)/).any?
  ENV['RAILS_ENV'] ||= 'test'
end

%w(
  active_record
  action_controller
  action_mailer
  rails/test_unit
  sprockets
).each do |framework|
  begin
    require "#{framework}/railtie"
  rescue LoadError
  end
end
