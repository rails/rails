require "action_mailer"
require "rails"

module ActionMailer
  class Railtie < Rails::Railtie
    railtie_name :action_mailer

    initializer "action_mailer.url_for", :before => :load_environment_config do |app|
      ActionMailer::Base.send(:include, ActionController::UrlFor) if defined?(ActionController)
    end

    require "action_mailer/railties/subscriber"
    subscriber ActionMailer::Railties::Subscriber.new

    initializer "action_mailer.logger" do
      ActionMailer::Base.logger ||= Rails.logger
    end

    initializer "action_mailer.set_configs" do |app|
      app.config.action_mailer.each do |k,v|
        ActionMailer::Base.send "#{k}=", v
      end
    end
  end
end