# frozen_string_literal: true

require "rails"
require "action_view"

module ActionView
  # = Action View Railtie
  class Railtie < Rails::Engine # :nodoc:
    config.action_view = ActiveSupport::OrderedOptions.new
    config.action_view.embed_authenticity_token_in_remote_forms = nil
    config.action_view.debug_missing_translation = true
    config.action_view.default_enforce_utf8 = nil
    config.action_view.image_loading = nil
    config.action_view.image_decoding = nil
    config.action_view.apply_stylesheet_media_default = true
    config.action_view.prepend_content_exfiltration_prevention = false

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
      prepend_content_exfiltration_prevention = app.config.action_view.delete(:prepend_content_exfiltration_prevention)
      ActionView::Helpers::ContentExfiltrationPreventionHelper.prepend_content_exfiltration_prevention = prepend_content_exfiltration_prevention
    end

    config.after_initialize do |app|
      if klass = app.config.action_view.delete(:sanitizer_vendor)
        ActionView::Helpers::SanitizeHelper.sanitizer_vendor = klass
      end
    end

    config.after_initialize do |app|
      button_to_generates_button_tag = app.config.action_view.delete(:button_to_generates_button_tag)
      unless button_to_generates_button_tag.nil?
        ActionView::Helpers::UrlHelper.button_to_generates_button_tag = button_to_generates_button_tag
      end
    end

    config.after_initialize do |app|
      frozen_string_literal = app.config.action_view.delete(:frozen_string_literal)
      ActionView::Template.frozen_string_literal = frozen_string_literal
    end

    config.after_initialize do |app|
      ActionView::Helpers::AssetTagHelper.image_loading = app.config.action_view.delete(:image_loading)
      ActionView::Helpers::AssetTagHelper.image_decoding = app.config.action_view.delete(:image_decoding)
      ActionView::Helpers::AssetTagHelper.preload_links_header = app.config.action_view.delete(:preload_links_header)
      ActionView::Helpers::AssetTagHelper.apply_stylesheet_media_default = app.config.action_view.delete(:apply_stylesheet_media_default)
    end

    config.after_initialize do |app|
      ActionView::Helpers::AssetTagHelper.auto_include_nonce_for_scripts = app.config.content_security_policy_nonce_auto && app.config.content_security_policy_nonce_directives.intersect?(["script-src", "script-src-elem", "script-src-attr"]) && app.config.content_security_policy_nonce_generator.present?
      ActionView::Helpers::AssetTagHelper.auto_include_nonce_for_styles = app.config.content_security_policy_nonce_auto && app.config.content_security_policy_nonce_directives.intersect?(["style-src", "style-src-elem", "style-src-attr"]) && app.config.content_security_policy_nonce_generator.present?
      ActionView::Helpers::JavaScriptHelper.auto_include_nonce = app.config.content_security_policy_nonce_auto && app.config.content_security_policy_nonce_directives.intersect?(["script-src", "script-src-elem", "script-src-attr"]) && app.config.content_security_policy_nonce_generator.present?
    end

    config.after_initialize do |app|
      config.after_initialize do
        ActionView.render_tracker = config.action_view.render_tracker
      end

      ActiveSupport.on_load(:action_view) do
        app.config.action_view.each do |k, v|
          next if k == :render_tracker
          send "#{k}=", v
        end
      end
    end

    initializer "action_view.deprecator", before: :load_environment_config do |app|
      app.deprecators[:action_view] = ActionView.deprecator
    end

    initializer "action_view.logger" do
      ActiveSupport.on_load(:action_view) { self.logger ||= Rails.logger }
    end

    initializer "action_view.caching" do |app|
      ActiveSupport.on_load(:action_view) do
        if app.config.action_view.cache_template_loading.nil?
          ActionView::Resolver.caching = !app.config.reloading_enabled?
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
        !app.config.reloading_enabled?
      else
        app.config.action_view.cache_template_loading
      end

      unless enable_caching
        view_reloader = ActionView::CacheExpiry::ViewReloader.new(watcher: app.config.file_watcher)

        app.reloaders << view_reloader
        app.reloader.to_run do
          require_unload_lock!
          view_reloader.execute
        end
      end
    end

    rake_tasks do |app|
      unless app.config.api_only
        load "action_view/tasks/cache_digests.rake"
      end
    end
  end
end
