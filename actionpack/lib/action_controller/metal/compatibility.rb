module ActionController
  module Compatibility
    extend ActiveSupport::Concern

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

      # TODO: Update protected instance variables list
      config_accessor :protected_instance_variables
      self.protected_instance_variables = %w(@assigns @performed_redirect @performed_render
                                             @variables_added @request_origin @url
                                             @parent_controller @action_name
                                             @before_filter_chain_aborted @_headers @_params
                                             @_response)

      def rescue_action(env)
        raise env["action_dispatch.rescue.exception"]
      end
    end

    # For old tests
    def initialize_template_class(*) end
    def assign_shortcuts(*) end

    def _normalize_options(options)
      if options[:action] && options[:action].to_s.include?(?/)
        ActiveSupport::Deprecation.warn "Giving a path to render :action is deprecated. " <<
          "Please use render :template instead", caller
        options[:template] = options.delete(:action)
      end

      options[:text] = nil if options.delete(:nothing) == true
      options[:text] = " " if options.key?(:text) && options[:text].nil?
      super
    end

    def render_to_body(options)
      options[:template].sub!(/^\//, '') if options.key?(:template)
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
  end
end
