module ActionController
  module Compatibility
    extend ActiveSupport::Concern

    # Temporary hax
    included do
      class << self
        delegate :default_charset=, :to => "ActionDispatch::Response"
      end

      self.protected_instance_variables = [
        :@_status, :@_headers, :@_params, :@_env, :@_response, :@_request,
        :@_view_runtime, :@_stream, :@_url_options, :@_action_has_layout
      ]
    end
  end
end
