require 'action_dispatch/http/parameter_filter'

module ActionDispatch
  module Http
    # Allows you to specify sensitive parameters which will be replaced from
    # the request log by looking in the query string of the request and all
    # sub-hashes of the params hash to filter. Filtering only certain sub-keys
    # from a hash is possible by using the dot notation: 'credit_card.number'.
    # If a block is given, each key and value of the params hash and all
    # sub-hashes is passed to it, the value or key can be replaced using
    # String#replace or similar method.
    #
    #   env["action_dispatch.parameter_filter"] = [:password]
    #   => replaces the value to all keys matching /password/i with "[FILTERED]"
    #
    #   env["action_dispatch.parameter_filter"] = [:foo, "bar"]
    #   => replaces the value to all keys matching /foo|bar/i with "[FILTERED]"
    #
    #   env["action_dispatch.parameter_filter"] = [ "credit_card.code" ]
    #   => replaces { credit_card: {code: "xxxx"} } with "[FILTERED]", does not
    #   change { file: { code: "xxxx"} }
    #
    #   env["action_dispatch.parameter_filter"] = -> (k, v) do
    #     v.reverse! if k =~ /secret/i
    #   end
    #   => reverses the value to all keys matching /secret/i
    module FilterParameters
      ENV_MATCH = [/RAW_POST_DATA/, "rack.request.form_vars"] # :nodoc:
      NULL_PARAM_FILTER = ParameterFilter.new # :nodoc:
      NULL_ENV_FILTER   = ParameterFilter.new ENV_MATCH # :nodoc:

      def initialize
        super
        @filtered_parameters = nil
        @filtered_env        = nil
        @filtered_path       = nil
      end

      # Returns a hash of parameters with all sensitive data replaced.
      def filtered_parameters
        @filtered_parameters ||= parameter_filter.filter(parameters)
      end

      # Returns a hash of request.env with all sensitive data replaced.
      def filtered_env
        @filtered_env ||= env_filter.filter(@env)
      end

      # Reconstructed a path with all sensitive GET parameters replaced.
      def filtered_path
        @filtered_path ||= query_string.empty? ? path : "#{path}?#{filtered_query_string}"
      end

    protected

      def parameter_filter
        parameter_filter_for fetch_header("action_dispatch.parameter_filter") {
          return NULL_PARAM_FILTER
        }
      end

      def env_filter
        user_key = fetch_header("action_dispatch.parameter_filter") {
          return NULL_ENV_FILTER
        }
        parameter_filter_for(Array(user_key) + ENV_MATCH)
      end

      def parameter_filter_for(filters)
        ParameterFilter.new(filters)
      end

      KV_RE   = '[^&;=]+'
      PAIR_RE = %r{(#{KV_RE})=(#{KV_RE})}
      def filtered_query_string
        query_string.gsub(PAIR_RE) do |_|
          parameter_filter.filter($1 => $2).first.join("=")
        end
      end
    end
  end
end
