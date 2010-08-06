require "action_mailer"
require "rails"
require "abstract_controller/railties/routes_helpers"
require "action_mailer/railties/paths"

module ActionMailer
  class Railtie < Rails::Railtie
    config.action_mailer = ActiveSupport::OrderedOptions.new

    initializer "action_mailer.logger" do
      ActiveSupport.on_load(:action_mailer) { self.logger ||= Rails.logger }
    end

    initializer "action_mailer.set_configs" do |app|
      options = app.config.action_mailer

      ActiveSupport.on_load(:action_mailer) do
        include AbstractController::UrlFor
        include app.routes.mounted_helpers(:app)
        extend ::AbstractController::Railties::RoutesHelpers.with(app.routes)
        extend ::ActionMailer::Railties::Paths.with(app)
        options.each { |k,v| send("#{k}=", v) }
      end
    end
  end
end
