# frozen_string_literal: true

require "action_view"
require "rails"

module ActionView
  # = Action View Railtie
  class Railtie < Rails::Engine # :nodoc:
    config.action_view = ActiveSupport::OrderedOptions.new
    config.action_view.embed_authenticity_token_in_remote_forms = nil
    config.action_view.debug_missing_translation = true
    config.action_view.default_enforce_utf8 = nil
    config.action_view.finalize_compiled_template_methods = true

    config.eager_load_namespaces << ActionView

    initializer "action_view.embed_authenticity_token_in_remote_forms" do |app|
      ActiveSupport.on_load(:action_view) do
        ActionView::Helpers::FormTagHelper.embed_authenticity_token_in_remote_forms =
          app.config.action_view.delete(:embed_authenticity_token_in_remote_forms)
      end
    end

    initializer "action_view.form_with_generates_remote_forms" do |app|
      ActiveSupport.on_load(:action_view) do
        form_with_generates_remote_forms = app.config.action_view.delete(:form_with_generates_remote_forms)
        ActionView::Helpers::FormHelper.form_with_generates_remote_forms = form_with_generates_remote_forms
      end
    end

    initializer "action_view.form_with_generates_ids" do |app|
      ActiveSupport.on_load(:action_view) do
        form_with_generates_ids = app.config.action_view.delete(:form_with_generates_ids)
        unless form_with_generates_ids.nil?
          ActionView::Helpers::FormHelper.form_with_generates_ids = form_with_generates_ids
        end
      end
    end

    initializer "action_view.default_enforce_utf8" do |app|
      ActiveSupport.on_load(:action_view) do
        default_enforce_utf8 = app.config.action_view.delete(:default_enforce_utf8)
        unless default_enforce_utf8.nil?
          ActionView::Helpers::FormTagHelper.default_enforce_utf8 = default_enforce_utf8
        end
      end
    end

    initializer "action_view.finalize_compiled_template_methods" do |app|
      ActiveSupport.on_load(:action_view) do
        ActionView::Template.finalize_compiled_template_methods =
          app.config.action_view.delete(:finalize_compiled_template_methods)
      end
    end

    initializer "action_view.logger" do
      ActiveSupport.on_load(:action_view) { self.logger ||= Rails.logger }
    end

    initializer "action_view.set_configs" do |app|
      ActiveSupport.on_load(:action_view) do
        app.config.action_view.each do |k, v|
          send "#{k}=", v
        end
      end
    end

    initializer "action_view.caching" do |app|
      ActiveSupport.on_load(:action_view) do
        if app.config.action_view.cache_template_loading.nil?
          ActionView::Resolver.caching = app.config.cache_classes
        end
      end
    end

    initializer "action_view.per_request_digest_cache" do |app|
      ActiveSupport.on_load(:action_view) do
        unless ActionView::Resolver.caching?
          app.executor.to_run ActionView::Digestor::PerExecutionDigestCacheExpiry
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

    rake_tasks do |app|
      unless app.config.api_only
        load "action_view/tasks/cache_digests.rake"
      end
    end
  end
end
