require "action_mailer"
require "rails"
require "abstract_controller/railties/routes_helpers"

module ActionMailer
  class Railtie < Rails::Railtie # :nodoc:
    config.action_mailer = ActiveSupport::OrderedOptions.new
    config.eager_load_namespaces << ActionMailer

    initializer "action_mailer.logger" do
      ActiveSupport.on_load(:action_mailer) { self.logger ||= Rails.logger }
    end

    initializer "action_mailer.set_configs" do |app|
      paths   = app.config.paths
      options = app.config.action_mailer

      options.assets_dir      ||= paths["public"].first
      options.javascripts_dir ||= paths["public/javascripts"].first
      options.stylesheets_dir ||= paths["public/stylesheets"].first

      # make sure readers methods get compiled
      options.asset_host          ||= app.config.asset_host
      options.relative_url_root   ||= app.config.relative_url_root

      ActiveSupport.on_load(:action_mailer) do
        include AbstractController::UrlFor
        extend ::AbstractController::Railties::RoutesHelpers.with(app.routes)
        include app.routes.mounted_helpers

        register_interceptors(options.delete(:interceptors))
        register_observers(options.delete(:observers))

        options.each { |k,v| send("#{k}=", v) }
      end
    end

    initializer "action_mailer.compile_config_methods" do
      ActiveSupport.on_load(:action_mailer) do
        config.compile_methods! if config.respond_to?(:compile_methods!)
      end
    end

    initializer "action_mailer.configure_mailer_previews", before: :set_autoload_paths do |app|
      if Rails.env.development?
        options = app.config.action_mailer
        options.preview_path ||= defined?(Rails.root) ? "#{Rails.root}/test/mailers/previews" : nil
        app.config.autoload_paths << options.preview_path
      end
    end
  end
end
