module ActionController
  module Compatibility
    extend ActiveSupport::Concern

    include AbstractController::Compatibility

    class ::ActionController::ActionControllerError < StandardError #:nodoc:
    end

    module ClassMethods
    end

    # Temporary hax
    included do
      ::ActionController::UnknownAction = ::AbstractController::ActionNotFound
      ::ActionController::DoubleRenderError = ::AbstractController::DoubleRenderError

      # ROUTES TODO: This should be handled by a middleware and route generation
      # should be able to handle SCRIPT_NAME
      self.config.relative_url_root = ENV['RAILS_RELATIVE_URL_ROOT']

      class << self
        delegate :default_charset=, :to => "ActionDispatch::Response"
      end

      # cattr_reader :protected_instance_variables
      cattr_accessor :protected_instance_variables
      self.protected_instance_variables = %w(@assigns @performed_redirect @performed_render
                                             @variables_added @request_origin @url
                                             @parent_controller @action_name
                                             @before_filter_chain_aborted @_headers @_params
                                             @_response)

      # Controls the resource action separator
      def self.resource_action_separator
        @resource_action_separator ||= "/"
      end

      def self.resource_action_separator=(val)
        ActiveSupport::Deprecation.warn "ActionController::Base.resource_action_separator is deprecated and only " \
                                        "works with the deprecated router DSL."
        @resource_action_separator = val
      end

      def self.use_accept_header
        ActiveSupport::Deprecation.warn "ActionController::Base.use_accept_header doesn't do anything anymore. " \
                                        "The accept header is always taken into account."
      end

      def self.use_accept_header=(val)
        use_accept_header
      end

      self.page_cache_directory = defined?(Rails.public_path) ? Rails.public_path : ""

      # Prepends all the URL-generating helpers from AssetHelper. This makes it possible to easily move javascripts, stylesheets,
      # and images to a dedicated asset server away from the main web server. Example:
      #   ActionController::Base.asset_host = "http://assets.example.com"
      cattr_accessor :asset_host
    end

    def self.deprecated_config_accessor(option, message = nil)
      deprecated_config_reader(option, message)
      deprecated_config_writer(option, message)
    end

    def self.deprecated_config_reader(option, message = nil)
      message ||= "Reading #{option} directly from ActionController::Base is deprecated. " \
                  "Please read it from config.#{option}"

      ClassMethods.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{option}
          ActiveSupport::Deprecation.warn #{message.inspect}, caller
          config.#{option}
        end
      RUBY
    end

    def self.deprecated_config_writer(option, message = nil)
      message ||= "Setting #{option} directly on ActionController::Base is deprecated. " \
                  "Please set it on config.action_controller.#{option}"

      ClassMethods.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{option}=(val)
          ActiveSupport::Deprecation.warn #{message.inspect}, caller
          config.#{option} = val
        end
      RUBY
    end

    deprecated_config_writer :session_store
    deprecated_config_writer :session_options
    deprecated_config_accessor :relative_url_root, "relative_url_root is ineffective. Please stop using it"
    deprecated_config_accessor :assets_dir
    deprecated_config_accessor :javascripts_dir
    deprecated_config_accessor :stylesheets_dir

    # For old tests
    def initialize_template_class(*) end
    def assign_shortcuts(*) end

    # TODO: Remove this after we flip
    def template
      @template ||= view_context
    end

    def process_action(*)
      template
      super
    end

    module ClassMethods
      def consider_all_requests_local
        ActiveSupport::Deprecation.warn "ActionController::Base.consider_all_requests_local is deprecated, " <<
          "use Rails.application.config.consider_all_requests_local instead", caller
        Rails.application.config.consider_all_requests_local
      end

      def consider_all_requests_local=(value)
        ActiveSupport::Deprecation.warn "ActionController::Base.consider_all_requests_local= is deprecated. " <<
          "Please configure it on your application with config.consider_all_requests_local=", caller
        Rails.application.config.consider_all_requests_local = value
      end

      def allow_concurrency
        ActiveSupport::Deprecation.warn "ActionController::Base.allow_concurrency is deprecated, " <<
          "use Rails.application.config.allow_concurrency instead", caller
        Rails.application.config.allow_concurrency
      end

      def allow_concurrency=(value)
        ActiveSupport::Deprecation.warn "ActionController::Base.allow_concurrency= is deprecated. " <<
          "Please configure it on your application with config.allow_concurrency=", caller
        Rails.application.config.allow_concurrency = value
      end

      def ip_spoofing_check=(value)
        ActiveSupport::Deprecation.warn "ActionController::Base.ip_spoofing_check= is deprecated. " <<
          "Please configure it on your application with config.action_dispatch.ip_spoofing_check=", caller
        Rails.application.config.action_disaptch.ip_spoofing_check = value
      end

      def ip_spoofing_check
        ActiveSupport::Deprecation.warn "ActionController::Base.ip_spoofing_check is deprecated. " <<
          "Configuring ip_spoofing_check on the application configures a middleware.", caller
        Rails.application.config.action_disaptch.ip_spoofing_check
      end

      def trusted_proxies=(value)
        ActiveSupport::Deprecation.warn "ActionController::Base.trusted_proxies= is deprecated. " <<
          "Please configure it on your application with config.action_dispatch.trusted_proxies=", caller
        Rails.application.config.action_dispatch.ip_spoofing_check = value
      end

      def trusted_proxies
        ActiveSupport::Deprecation.warn "ActionController::Base.trusted_proxies is deprecated. " <<
          "Configuring trusted_proxies on the application configures a middleware.", caller
        Rails.application.config.action_dispatch.ip_spoofing_check = value
      end

      def session=(value)
        ActiveSupport::Deprecation.warn "ActionController::Base.session= is deprecated. " <<
          "Please configure it on your application with config.action_dispatch.session=", caller
        Rails.application.config.action_dispatch.session = value.delete(:disabled) ? nil : value
      end

      def rescue_action(env)
        raise env["action_dispatch.rescue.exception"]
      end

      # Defines the storage option for cached fragments
      def cache_store=(store_option)
        @@cache_store = ActiveSupport::Cache.lookup_store(store_option)
      end
    end

    delegate :consider_all_requests_local, :consider_all_requests_local=,
             :allow_concurrency, :allow_concurrency=, :to => :"self.class"

    def render_to_body(options)
      if options.is_a?(Hash) && options.key?(:template)
        options[:template].sub!(/^\//, '')
      end

      options[:text] = nil if options.delete(:nothing) == true
      options[:text] = " " if options.key?(:text) && options[:text].nil?

      super || " "
    end

    def _handle_method_missing
      method_missing(@_action_name.to_sym)
    end

    def method_for_action(action_name)
      super || (respond_to?(:method_missing) && "_handle_method_missing")
    end

    def performed?
      response_body
    end

    # ==== Request only view path switching ====
    def append_view_path(path)
      view_paths.push(*path)
    end

    def prepend_view_path(path)
      view_paths.unshift(*path)
    end

    def view_paths
      view_context.view_paths
    end
  end
end
