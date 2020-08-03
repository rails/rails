# frozen_string_literal: true

require "action_view"
require "rails"

module ActionView
  # = Action View Railtie
  class Railtie < Rails::Engine # :nodoc:
    NULL_OPTION = Object.new

    config.action_view = ActiveSupport::OrderedOptions.new
    config.action_view.embed_authenticity_token_in_remote_forms = nil
    config.action_view.debug_missing_translation = true
    config.action_view.default_enforce_utf8 = nil
    config.action_view.finalize_compiled_template_methods = NULL_OPTION

    config.eager_load_namespaces << ActionView

    config.after_initialize do |app|
      ActionView::Helpers::FormTagHelper.embed_authenticity_token_in_remote_forms =
        app.config.action_view.delete(:embed_authenticity_token_in_remote_forms)
    end

    config.after_initialize do |app|
      form_with_generates_remote_forms = app.config.action_view.delete(:form_with_generates_remote_forms)
      ActionView::Helpers::FormHelper.form_with_generates_remote_forms = form_with_generates_remote_forms
    end

    config.after_initialize do |app|
      form_with_generates_ids = app.config.action_view.delete(:form_with_generates_ids)
      unless form_with_generates_ids.nil?
        ActionView::Helpers::FormHelper.form_with_generates_ids = form_with_generates_ids
      end
    end

    config.after_initialize do |app|
      default_enforce_utf8 = app.config.action_view.delete(:default_enforce_utf8)
      unless default_enforce_utf8.nil?
        ActionView::Helpers::FormTagHelper.default_enforce_utf8 = default_enforce_utf8
      end
    end

    config.after_initialize do |app|
      ActiveSupport.on_load(:action_view) do
        app.config.action_view.each do |k, v|
          if k == :raise_on_missing_translations
            ActiveSupport::Deprecation.warn \
              "action_view.raise_on_missing_translations is deprecated and will be removed in Rails 6.2. " \
              "Set i18n.raise_on_missing_translations instead. " \
              "Note that this new setting also affects how missing translations are handled in controllers."
          end
          send "#{k}=", v
        end
      end
    end

    initializer "action_view.finalize_compiled_template_methods" do |app|
      ActiveSupport.on_load(:action_view) do
        option = app.config.action_view.delete(:finalize_compiled_template_methods)

        if option != NULL_OPTION
          ActiveSupport::Deprecation.warn "action_view.finalize_compiled_template_methods is deprecated and has no effect"
        end
      end
    end

    initializer "action_view.logger" do
      ActiveSupport.on_load(:action_view) { self.logger ||= Rails.logger }
    end

    initializer "action_view.caching" do |app|
      ActiveSupport.on_load(:action_view) do
        if app.config.action_view.cache_template_loading.nil?
          ActionView::Resolver.caching = app.config.cache_classes
        end
      end
    end

    initializer "action_view.setup_action_pack" do |app|
      ActiveSupport.on_load(:action_controller) do
        ActionView::RoutingUrlFor.include(ActionDispatch::Routing::UrlFor)
      end
    end

    initializer "action_view.collection_caching", after: "action_controller.set_configs" do |app|
      PartialRenderer.collection_cache = app.config.action_controller.cache_store
    end

    config.after_initialize do |app|
      enable_caching = if app.config.action_view.cache_template_loading.nil?
        app.config.cache_classes
      else
        app.config.action_view.cache_template_loading
      end

      unless enable_caching
        app.executor.to_run ActionView::CacheExpiry::Executor.new(watcher: app.config.file_watcher)
      end
    end

    rake_tasks do |app|
      unless app.config.api_only
        load "action_view/tasks/cache_digests.rake"
      end
    end
  end
end
