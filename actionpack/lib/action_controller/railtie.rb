# frozen_string_literal: true

require "rails"
require "action_controller"
require "action_dispatch/railtie"
require "abstract_controller/railties/routes_helpers"
require "action_controller/railties/helpers"
require "action_view/railtie"

module ActionController
  class Railtie < Rails::Railtie # :nodoc:
    config.action_controller = ActiveSupport::OrderedOptions.new
    config.action_controller.raise_on_open_redirects = false
    config.action_controller.log_query_tags_around_actions = true
    config.action_controller.wrap_parameters_by_default = false

    config.eager_load_namespaces << ActionController

    initializer "action_controller.assets_config", group: :all do |app|
      app.config.action_controller.assets_dir ||= app.config.paths["public"].first
    end

    initializer "action_controller.set_helpers_path" do |app|
      ActionController::Helpers.helpers_path = app.helpers_paths
    end

    initializer "action_controller.parameters_config" do |app|
      options = app.config.action_controller

      ActiveSupport.on_load(:action_controller, run_once: true) do
        ActionController::Parameters.permit_all_parameters = options.permit_all_parameters || false
        if app.config.action_controller[:always_permitted_parameters]
          ActionController::Parameters.always_permitted_parameters =
            app.config.action_controller.always_permitted_parameters
        end

        action_on_unpermitted_parameters = options.action_on_unpermitted_parameters

        if action_on_unpermitted_parameters.nil?
          action_on_unpermitted_parameters = (Rails.env.test? || Rails.env.development?) ? :log : false
        end

        ActionController::Parameters.action_on_unpermitted_parameters = action_on_unpermitted_parameters
      end
    end

    initializer "action_controller.set_configs" do |app|
      paths   = app.config.paths
      options = app.config.action_controller

      options.logger      ||= Rails.logger
      options.cache_store ||= Rails.cache

      options.javascripts_dir ||= paths["public/javascripts"].first
      options.stylesheets_dir ||= paths["public/stylesheets"].first

      # Ensure readers methods get compiled.
      options.asset_host        ||= app.config.asset_host
      options.relative_url_root ||= app.config.relative_url_root

      ActiveSupport.on_load(:action_controller) do
        include app.routes.mounted_helpers
        extend ::AbstractController::Railties::RoutesHelpers.with(app.routes)
        extend ::ActionController::Railties::Helpers

        wrap_parameters format: [:json] if options.wrap_parameters_by_default && respond_to?(:wrap_parameters)

        # Configs used in other initializers
        filtered_options = options.except(
          :log_query_tags_around_actions,
          :permit_all_parameters,
          :action_on_unpermitted_parameters,
          :always_permitted_parameters,
          :wrap_parameters_by_default
        )

        filtered_options.each do |k, v|
          k = "#{k}="
          if respond_to?(k)
            send(k, v)
          elsif !Base.respond_to?(k)
            raise "Invalid option key: #{k}"
          end
        end
      end
    end

    initializer "action_controller.compile_config_methods" do
      ActiveSupport.on_load(:action_controller) do
        config.compile_methods! if config.respond_to?(:compile_methods!)
      end
    end

    initializer "action_controller.request_forgery_protection" do |app|
      ActiveSupport.on_load(:action_controller_base) do
        if app.config.action_controller.default_protect_from_forgery
          protect_from_forgery with: :exception
        end
      end
    end

    initializer "action_controller.eager_load_actions" do
      ActiveSupport.on_load(:after_initialize) do
        ActionController::Metal.descendants.each(&:action_methods) if config.eager_load
      end
    end

    initializer "action_controller.query_log_tags" do |app|
      query_logs_tags_enabled = app.config.respond_to?(:active_record) &&
        app.config.active_record.query_log_tags_enabled &&
        app.config.action_controller.log_query_tags_around_actions

      if query_logs_tags_enabled
        app.config.active_record.query_log_tags |= [:controller] unless app.config.active_record.query_log_tags.include?(:namespaced_controller)
        app.config.active_record.query_log_tags |= [:action]

        ActiveSupport.on_load(:active_record) do
          ActiveRecord::QueryLogs.taggings.merge!(
            controller:            ->(context) { context[:controller]&.controller_name },
            action:                ->(context) { context[:controller]&.action_name },
            namespaced_controller: ->(context) { context[:controller].class.name if context[:controller] }
          )
        end
      end
    end

    initializer "action_controller.test_case" do |app|
      ActiveSupport.on_load(:action_controller_test_case) do
        ActionController::TestCase.executor_around_each_request = app.config.active_support.executor_around_test_case
      end
    end
  end
end
