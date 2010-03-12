require "action_mailer"
require "rails"

module ActionMailer
  class Railtie < Rails::Railtie
    railtie_name :action_mailer

    initializer "action_mailer.url_for", :before => :load_environment_config do |app|
      ActionMailer.base_hook { include app.routes.url_helpers }
    end

    require "action_mailer/railties/log_subscriber"
    log_subscriber ActionMailer::Railties::LogSubscriber.new

    initializer "action_mailer.logger" do
      ActionMailer.base_hook { self.logger ||= Rails.logger }
    end

    initializer "action_mailer.set_configs" do |app|
      ActionMailer.base_hook do
        app.config.action_mailer.each do |k,v|
          send "#{k}=", v
        end
      end
    end
  end
end