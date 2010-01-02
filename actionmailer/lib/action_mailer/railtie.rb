require "action_mailer"
require "rails"

module ActionMailer
  class Railtie < Rails::Railtie
    plugin_name :action_mailer

    initializer "action_mailer.set_configs" do |app|
      app.config.action_mailer.each do |k,v|
        ActionMailer::Base.send "#{k}=", v
      end
    end

    # TODO: ActionController::Base.logger should delegate to its own config.logger
    initializer "action_mailer.logger" do
      ActionMailer::Base.logger ||= Rails.logger
    end

    initializer "action_mailer.view_paths" do |app|
      # TODO: this should be combined with the logic for default config.action_mailer.view_paths
      view_path = ActionView::PathSet.type_cast(app.config.view_path, app.config.cache_classes)
      ActionMailer::Base.template_root = view_path if ActionMailer::Base.view_paths.blank?
    end
  end
end