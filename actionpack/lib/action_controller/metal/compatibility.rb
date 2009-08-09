module ActionController
  module Rails2Compatibility
    extend ActiveSupport::Concern

    class ::ActionController::ActionControllerError < StandardError #:nodoc:
    end

    # Temporary hax
    included do
      ::ActionController::UnknownAction = ::AbstractController::ActionNotFound
      ::ActionController::DoubleRenderError = ::AbstractController::DoubleRenderError

      cattr_accessor :session_options
      self.session_options = {}

      cattr_accessor :allow_concurrency
      self.allow_concurrency = false

      cattr_accessor :param_parsers
      self.param_parsers = { Mime::MULTIPART_FORM   => :multipart_form,
                             Mime::URL_ENCODED_FORM => :url_encoded_form,
                             Mime::XML              => :xml_simple,
                             Mime::JSON             => :json }

      cattr_accessor :relative_url_root
      self.relative_url_root = ENV['RAILS_RELATIVE_URL_ROOT']

      cattr_accessor :default_charset
      self.default_charset = "utf-8"

      # cattr_reader :protected_instance_variables
      cattr_accessor :protected_instance_variables
      self.protected_instance_variables = %w(@assigns @performed_redirect @performed_render @variables_added @request_origin @url @parent_controller
                                          @action_name @before_filter_chain_aborted @action_cache_path @_headers @_params
                                          @_flash @_response)

      # Indicates whether or not optimise the generated named
      # route helper methods
      cattr_accessor :optimise_named_routes
      self.optimise_named_routes = true

      cattr_accessor :resources_path_names
      self.resources_path_names = { :new => 'new', :edit => 'edit' }

      # Controls the resource action separator
      cattr_accessor :resource_action_separator
      self.resource_action_separator = "/"

      cattr_accessor :use_accept_header
      self.use_accept_header = true

      cattr_accessor :page_cache_directory
      self.page_cache_directory = defined?(Rails.public_path) ? Rails.public_path : ""

      cattr_reader :cache_store

      cattr_accessor :consider_all_requests_local
      self.consider_all_requests_local = true

      # Prepends all the URL-generating helpers from AssetHelper. This makes it possible to easily move javascripts, stylesheets,
      # and images to a dedicated asset server away from the main web server. Example:
      #   ActionController::Base.asset_host = "http://assets.example.com"
      cattr_accessor :asset_host

      cattr_accessor :ip_spoofing_check
      self.ip_spoofing_check = true

      cattr_accessor :trusted_proxies
    end

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
      end

      def rescue_action(env)
        raise env["action_dispatch.rescue.exception"]
      end

      # Defines the storage option for cached fragments
      def cache_store=(store_option)
        @@cache_store = ActiveSupport::Cache.lookup_store(store_option)
      end
    end

    def render_to_body(options)
      if options.is_a?(Hash) && options.key?(:template)
        options[:template].sub!(/^\//, '')
      end

      options[:text] = nil if options[:nothing] == true

      body = super
      body = [' '] if body.blank?
      body
    end

    def _handle_method_missing
      method_missing(@_action_name.to_sym)
    end

    def method_for_action(action_name)
      super || (respond_to?(:method_missing) && "_handle_method_missing")
    end

    def _find_layout(name, details)
      details[:prefix] = nil if name =~ /\blayouts/
      super
    end
    
    # Move this into a "don't run in production" module
    def _default_layout(details, require_layout = false)
      super
    rescue ActionView::MissingTemplate
      _find_layout(_layout({}), {})
      nil
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
