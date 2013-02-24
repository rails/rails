require 'active_support/deprecation'

module ActionController
  module Compatibility
    extend ActiveSupport::Concern

    # Temporary hax
    included do
      ::ActionController::UnknownAction = ActiveSupport::Deprecation::DeprecatedConstantProxy.new('ActionController::UnknownAction', '::AbstractController::ActionNotFound')
      ::ActionController::DoubleRenderError = ActiveSupport::Deprecation::DeprecatedConstantProxy.new('ActionController::DoubleRenderError', '::AbstractController::DoubleRenderError')

      # ROUTES TODO: This should be handled by a middleware and route generation
      # should be able to handle SCRIPT_NAME
      self.config.relative_url_root = ENV['RAILS_RELATIVE_URL_ROOT']

      def self.default_charset=(new_charset)
        ActiveSupport::Deprecation.warn "Setting default charset at controller level" \
          " is deprecated, please use `config.action_dispatch.default_charset` instead", caller
        ActionDispatch::Response.default_charset = new_charset
      end

      self.protected_instance_variables = %w(
        @_status @_headers @_params @_env @_response @_request
        @_view_runtime @_stream @_url_options @_action_has_layout
      )

      def rescue_action(env)
        ActiveSupport::Deprecation.warn "Calling `rescue_action` is deprecated and will be removed in Rails 4.0.", caller
        raise env["action_dispatch.rescue.exception"]
      end
    end

    # For old tests
    def initialize_template_class(*)
      ActiveSupport::Deprecation.warn "Calling `initialize_template_class` is deprecated and has no effect anymore.", caller
    end

    def assign_shortcuts(*)
      ActiveSupport::Deprecation.warn "Calling `assign_shortcuts` is deprecated and has no effect anymore.", caller
    end

    def _normalize_options(options)
      options[:text] = nil if options.delete(:nothing) == true
      options[:text] = " " if options.key?(:text) && options[:text].nil?
      super
    end

    def render_to_body(options)
      options[:template].sub!(/^\//, '') if options.key?(:template)
      super || " "
    end

    def _handle_method_missing
      ActiveSupport::Deprecation.warn "Using `method_missing` to handle non" \
        " existing actions is deprecated and will be removed in Rails 4.0, " \
        " please use `action_missing` instead.", caller
      method_missing(@_action_name.to_sym)
    end

    def method_for_action(action_name)
      super || ((self.class.public_method_defined?(:method_missing) ||
        self.class.protected_method_defined?(:method_missing)) && "_handle_method_missing")
    end
  end
end
