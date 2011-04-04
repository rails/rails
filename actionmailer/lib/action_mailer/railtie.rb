require "action_mailer"
require "rails"

module ActionMailer
  class Railtie < Rails::Railtie
    config.action_mailer = ActiveSupport::OrderedOptions.new

    initializer "action_mailer.logger" do
      ActiveSupport.on_load(:action_mailer) { self.logger ||= Rails.logger }
    end

    initializer "action_mailer.set_configs" do |app|
      paths   = app.config.paths
      options = app.config.action_mailer

      options.assets_dir      ||= paths.public.to_a.first
      options.javascripts_dir ||= paths.public.javascripts.to_a.first
      options.stylesheets_dir ||= paths.public.stylesheets.to_a.first

      ActiveSupport.on_load(:action_mailer) do
        include app.routes.url_helpers

        register_interceptors(options.delete(:interceptors))
        register_observers(options.delete(:observers))

        options.each { |k,v| send("#{k}=", v) }
      end
    end
  end
end