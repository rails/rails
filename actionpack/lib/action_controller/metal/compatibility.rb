module ActionController
  module Compatibility
    extend ActiveSupport::Concern

    # Temporary hax
    included do
      # ROUTES TODO: This should be handled by a middleware and route generation
      # should be able to handle SCRIPT_NAME
      self.config.relative_url_root = ENV['RAILS_RELATIVE_URL_ROOT']

      class << self
        delegate :default_charset=, :to => "ActionDispatch::Response"
      end

      self.protected_instance_variables = [
        :@_status, :@_headers, :@_params, :@_env, :@_response, :@_request,
        :@_view_runtime, :@_stream, :@_url_options, :@_action_has_layout
      ]
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
