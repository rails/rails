# frozen_string_literal: true

require "active_job/railtie"
require "action_mailer"
require "rails"
require "abstract_controller/railties/routes_helpers"

module ActionMailer
  class Railtie < Rails::Railtie # :nodoc:
    config.action_mailer = ActiveSupport::OrderedOptions.new
    config.action_mailer.preview_paths = []
    config.eager_load_namespaces << ActionMailer

    initializer "action_mailer.deprecator", before: :load_environment_config do |app|
      app.deprecators[:action_mailer] = ActionMailer.deprecator
    end

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
      options.cache_store ||= Rails.cache
      options.preview_paths |= ["#{Rails.root}/test/mailers/previews"]

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
        self.preview_paths |= options[:preview_paths]

        if delivery_job = options.delete(:delivery_job)
          self.delivery_job = delivery_job.constantize
        end

        if options.smtp_settings
          self.smtp_settings = options.smtp_settings
        end

        smtp_timeout = options.delete(:smtp_timeout)

        if self.smtp_settings && smtp_timeout
          self.smtp_settings[:open_timeout] ||= smtp_timeout
          self.smtp_settings[:read_timeout] ||= smtp_timeout
        end

        options.each { |k, v| send("#{k}=", v) }
      end

      ActiveSupport.on_load(:action_dispatch_integration_test) do
        include ActionMailer::TestHelper
        include ActionMailer::TestCase::ClearTestDeliveries
      end
    end

    initializer "action_mailer.set_autoload_paths", before: :set_autoload_paths do |app|
      options = app.config.action_mailer
      app.config.paths["test/mailers/previews"].concat(options.preview_paths)
    end

    initializer "action_mailer.compile_config_methods" do
      ActiveSupport.on_load(:action_mailer) do
        config.compile_methods! if config.respond_to?(:compile_methods!)
      end
    end

    config.after_initialize do |app|
      options = app.config.action_mailer

      if options.show_previews
        app.routes.prepend do
          get "/rails/mailers" => "rails/mailers#index", internal: true
          get "/rails/mailers/download/*path" => "rails/mailers#download", internal: true
          get "/rails/mailers/*path" => "rails/mailers#preview", internal: true
        end
      end
    end
  end
end
