require "action_mailer"
require "rails"

module ActionMailer
  class Railtie < Rails::Railtie
    config.action_mailer = ActiveSupport::OrderedOptions.new

    require "action_mailer/railties/log_subscriber"
    log_subscriber :action_mailer, ActionMailer::Railties::LogSubscriber.new

    initializer "action_mailer.logger" do
      ActiveSupport.on_load(:action_mailer) { self.logger ||= Rails.logger }
    end

    initializer "action_mailer.set_configs" do |app|
      paths = app.config.paths
      am = app.config.action_mailer

      am.assets_dir      ||= paths.public.to_a.first
      am.javascripts_dir ||= paths.public.javascripts.to_a.first
      am.stylesheets_dir ||= paths.public.stylesheets.to_a.first

      ActiveSupport.on_load(:action_mailer) do
        self.config.merge!(am)

        include app.routes.url_helpers

        app.config.action_mailer.each do |k,v|
          send "#{k}=", v
        end
      end
    end
  end
end