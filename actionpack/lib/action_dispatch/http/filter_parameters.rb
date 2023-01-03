# frozen_string_literal: true

require "active_support/parameter_filter"

module ActionDispatch
  module Http
    # Allows you to specify sensitive query string and POST parameters to filter
    # from the request log.
    #
    #   # Replaces values with "[FILTERED]" for keys that match /foo|bar/i.
    #   env["action_dispatch.parameter_filter"] = [:foo, "bar"]
    #
    # For more information about filter behavior, see ActiveSupport::ParameterFilter.
    module FilterParameters
      ENV_MATCH = [/RAW_POST_DATA/, "rack.request.form_vars"] # :nodoc:
      NULL_PARAM_FILTER = ActiveSupport::ParameterFilter.new # :nodoc:
      NULL_ENV_FILTER   = ActiveSupport::ParameterFilter.new ENV_MATCH # :nodoc:

      def initialize
        super
        @filtered_parameters = nil
        @filtered_env        = nil
        @filtered_path       = nil
      end

      # Returns a hash of parameters with all sensitive data replaced.
      def filtered_parameters
        @filtered_parameters ||= parameter_filter.filter(parameters)
      rescue ActionDispatch::Http::Parameters::ParseError
        @filtered_parameters = {}
      end

      # Returns a hash of request.env with all sensitive data replaced.
      def filtered_env
        @filtered_env ||= env_filter.filter(@env)
      end

      # Reconstructs a path with all sensitive GET parameters replaced.
      def filtered_path
        @filtered_path ||= query_string.empty? ? path : "#{path}?#{filtered_query_string}"
      end

    private
      def parameter_filter # :doc:
        parameter_filter_for fetch_header("action_dispatch.parameter_filter") {
          return NULL_PARAM_FILTER
        }
      end

      def env_filter # :doc:
        user_key = fetch_header("action_dispatch.parameter_filter") {
          return NULL_ENV_FILTER
        }
        parameter_filter_for(Array(user_key) + ENV_MATCH)
      end

      def parameter_filter_for(filters) # :doc:
        ActiveSupport::ParameterFilter.new(filters)
      end

      KV_RE   = "[^&;=]+"
      PAIR_RE = %r{(#{KV_RE})=(#{KV_RE})}
      def filtered_query_string # :doc:
        query_string.gsub(PAIR_RE) do |_|
          parameter_filter.filter($1 => $2).first.join("=")
        end
      end
    end
  end
end
