require "action_mailer"
require "rails"

module ActionMailer
  class Railtie < Rails::Railtie
    config.action_mailer = ActiveSupport::OrderedOptions.new

    initializer "action_mailer.url_for", :before => :load_environment_config do |app|
      ActiveSupport.on_load(:action_mailer) { include app.routes.url_helpers }
    end

    require "action_mailer/railties/log_subscriber"
    log_subscriber :action_mailer, ActionMailer::Railties::LogSubscriber.new

    initializer "action_mailer.logger" do
      ActiveSupport.on_load(:action_mailer) { self.logger ||= Rails.logger }
    end

    initializer "action_mailer.set_configs" do |app|
      ActiveSupport.on_load(:action_mailer) do
        app.config.action_mailer.each do |k,v|
          send "#{k}=", v
        end
      end
    end
  end
end