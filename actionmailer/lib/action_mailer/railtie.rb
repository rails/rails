require 'active_job/railtie'
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
      options.show_previews = Rails.env.development? if options.show_previews.nil?

      if options.show_previews
        options.preview_path  ||= defined?(Rails.root) ? "#{Rails.root}/test/mailers/previews" : nil
      end

      # make sure readers methods get compiled
      options.asset_host          ||= app.config.asset_host
      options.relative_url_root   ||= app.config.relative_url_root

      ActiveSupport.on_load(:action_mailer) do
        include AbstractController::UrlFor
        extend ::AbstractController::Railties::RoutesHelpers.with(app.routes, false)
        include app.routes.mounted_helpers

        register_interceptors(options.delete(:interceptors))
        register_preview_interceptors(options.delete(:preview_interceptors))
        register_observers(options.delete(:observers))

        options.each { |k,v| send("#{k}=", v) }

        if options.show_previews
          app.routes.append do
            get '/rails/mailers'         => "rails/mailers#index"
            get '/rails/mailers/*path'   => "rails/mailers#preview"
          end
        end
      end
    end

    initializer "action_mailer.compile_config_methods" do
      ActiveSupport.on_load(:action_mailer) do
        config.compile_methods! if config.respond_to?(:compile_methods!)
      end
    end

    config.after_initialize do
      if ActionMailer::Base.preview_path
        ActiveSupport::Dependencies.autoload_paths << ActionMailer::Base.preview_path
      end
    end
  end
end
