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

      def rescue_action(env)
        raise env["action_dispatch.rescue.exception"]
      end

      # Defines the storage option for cached fragments
      def cache_store=(store_option)
        @@cache_store = ActiveSupport::Cache.lookup_store(store_option)
      end

      self.page_cache_directory = defined?(Rails.public_path) ? Rails.public_path : ""
    end

    # For old tests
    def initialize_template_class(*) end
    def assign_shortcuts(*) end

    def template
      @template ||= view_context
    end

    def process_action(*)
      template
      super
    end

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
