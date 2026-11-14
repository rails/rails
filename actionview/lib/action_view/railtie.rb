# frozen_string_literal: true

require "rails"
require "action_view"

module ActionView
  # Action View Railtie
  # ===================
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

    guard_load_hooks(:action_view, :action_view_test_case)

    # The helpers' settings are read here, but applied when the helpers are loaded,
    # so that booting doesn't load them.
    config.after_initialize do |app|
      embed_authenticity_token_in_remote_forms = app.config.action_view.delete(:embed_authenticity_token_in_remote_forms)
      ActiveSupport.on_load(:action_view_helpers) do
        ActionView::Helpers::FormTagHelper.embed_authenticity_token_in_remote_forms = embed_authenticity_token_in_remote_forms
      end
    end

    config.after_initialize do |app|
      form_with_generates_remote_forms = app.config.action_view.delete(:form_with_generates_remote_forms)
      ActiveSupport.on_load(:action_view_helpers) do
        ActionView::Helpers::FormHelper.form_with_generates_remote_forms = form_with_generates_remote_forms
      end
    end

    config.after_initialize do |app|
      form_with_generates_ids = app.config.action_view.delete(:form_with_generates_ids)
      unless form_with_generates_ids.nil?
        ActiveSupport.on_load(:action_view_helpers) do
          ActionView::Helpers::FormHelper.form_with_generates_ids = form_with_generates_ids
        end
      end
    end

    config.after_initialize do |app|
      default_enforce_utf8 = app.config.action_view.delete(:default_enforce_utf8)
      unless default_enforce_utf8.nil?
        ActiveSupport.on_load(:action_view_helpers) do
          ActionView::Helpers::FormTagHelper.default_enforce_utf8 = default_enforce_utf8
        end
      end
    end

    config.after_initialize do |app|
      prepend_content_exfiltration_prevention = app.config.action_view.delete(:prepend_content_exfiltration_prevention)
      ActiveSupport.on_load(:action_view_helpers) do
        ActionView::Helpers::ContentExfiltrationPreventionHelper.prepend_content_exfiltration_prevention = prepend_content_exfiltration_prevention
      end
    end

    config.after_initialize do |app|
      if klass = app.config.action_view.delete(:sanitizer_vendor)
        ActiveSupport.on_load(:action_view_helpers) do
          ActionView::Helpers::SanitizeHelper.sanitizer_vendor = klass
        end
      end
    end

    config.after_initialize do |app|
      button_to_generates_button_tag = app.config.action_view.delete(:button_to_generates_button_tag)
      unless button_to_generates_button_tag.nil?
        ActiveSupport.on_load(:action_view_helpers) do
          ActionView::Helpers::NavigationHelper.button_to_generates_button_tag = button_to_generates_button_tag
        end
      end
    end

    config.after_initialize do |app|
      frozen_string_literal = app.config.action_view.delete(:frozen_string_literal)
      ActionView::Template.frozen_string_literal = frozen_string_literal
    end

    config.after_initialize do
      ActiveSupport::Ractors.make_shareable(ActionView::Template::Handlers::ERB.escape_ignore_list)
    end

    config.after_initialize do |app|
      image_loading = app.config.action_view.delete(:image_loading)
      image_decoding = app.config.action_view.delete(:image_decoding)
      preload_links_header = app.config.action_view.delete(:preload_links_header)
      apply_stylesheet_media_default = app.config.action_view.delete(:apply_stylesheet_media_default)
      ActiveSupport.on_load(:action_view_helpers) do
        ActionView::Helpers::AssetTagHelper.image_loading = image_loading
        ActionView::Helpers::AssetTagHelper.image_decoding = image_decoding
        ActionView::Helpers::AssetTagHelper.preload_links_header = preload_links_header
        ActionView::Helpers::AssetTagHelper.apply_stylesheet_media_default = apply_stylesheet_media_default
      end
    end

    config.after_initialize do |app|
      auto_include_nonce_for_scripts = app.config.content_security_policy_nonce_auto && app.config.content_security_policy_nonce_directives.intersect?(["script-src", "script-src-elem", "script-src-attr"]) && app.config.content_security_policy_nonce_generator.present?
      auto_include_nonce_for_styles = app.config.content_security_policy_nonce_auto && app.config.content_security_policy_nonce_directives.intersect?(["style-src", "style-src-elem", "style-src-attr"]) && app.config.content_security_policy_nonce_generator.present?
      ActiveSupport.on_load(:action_view_helpers) do
        ActionView::Helpers::AssetTagHelper.auto_include_nonce_for_scripts = auto_include_nonce_for_scripts
        ActionView::Helpers::AssetTagHelper.auto_include_nonce_for_styles = auto_include_nonce_for_styles
        ActionView::Helpers::JavaScriptHelper.auto_include_nonce = auto_include_nonce_for_scripts
      end
    end

    config.after_initialize do |app|
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

    initializer "action_view.root" do
      ActiveSupport.on_load(:action_view) do
        ActionView::StructuredEventSubscriber.rails_root = "#{Rails.root}/".freeze
        ActionView::LogSubscriber.rails_root = "#{Rails.root}/".freeze
      end
    end

    initializer "action_view.caching" do |app|
      ActiveSupport.on_load(:action_view) do
        if app.config.action_view.cache_template_loading.nil?
          ActionView::Resolver.caching = !app.config.reloading_enabled?
        end
      end
    end

    initializer "action_view.set_render_tracker" do |app|
      ActionView.render_tracker = app.config.action_view.render_tracker
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
        view_reloader = ActionView::CacheExpiry::ViewReloader.create(watcher: app.config.file_watcher)

        app.reloaders << view_reloader
        app.reloader.to_run do
          require_unload_lock!
          view_reloader.execute
        end
      end
    end

    initializer "action_view.ractorize" do
      ActiveSupport.on_load(:before_ractorize) do
        ActionView::PathRegistry.make_shareable!
        ActionView::DependencyTracker.share_registry
      end
    end

    rake_tasks do |app|
      unless app.config.api_only
        load "action_view/tasks/cache_digests.rake"
        load "action_view/tasks/herb.rake"
      end
    end
  end
end
