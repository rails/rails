require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/object/duplicable'

module ActionDispatch
  module Http
    # Allows you to specify sensitive parameters which will be replaced from
    # the request log by looking in the query string of the request and all
    # subhashes of the params hash to filter. If a block is given, each key and
    # value of the params hash and all subhashes is passed to it, the value
    # or key can be replaced using String#replace or similar method.
    #
    #   env["action_dispatch.parameter_filter"] = [:password]
    #   => replaces the value to all keys matching /password/i with "[FILTERED]"
    #
    #   env["action_dispatch.parameter_filter"] = [:foo, "bar"]
    #   => replaces the value to all keys matching /foo|bar/i with "[FILTERED]"
    #
    #   env["action_dispatch.parameter_filter"] = lambda do |k,v|
    #     v.reverse! if k =~ /secret/i
    #   end
    #   => reverses the value to all keys matching /secret/i
    module FilterParameters
      extend ActiveSupport::Concern

      @@parameter_filter_for  = {}

      # Return a hash of parameters with all sensitive data replaced.
      def filtered_parameters
        @filtered_parameters ||= parameter_filter.filter(parameters)
      end

      # Return a hash of request.env with all sensitive data replaced.
      def filtered_env
        @filtered_env ||= env_filter.filter(@env)
      end

      # Reconstructed a path with all sensitive GET parameters replaced.
      def filtered_path
        @filtered_path ||= query_string.empty? ? path : "#{path}?#{filtered_query_string}"
      end

    protected

      def parameter_filter
        parameter_filter_for(@env["action_dispatch.parameter_filter"])
      end

      def env_filter
        parameter_filter_for(Array(@env["action_dispatch.parameter_filter"]) + [/RAW_POST_DATA/, "rack.request.form_vars"])
      end

      def parameter_filter_for(filters)
        @@parameter_filter_for[filters] ||= ParameterFilter.new(filters)
      end

      KV_RE   = '[^&;=]+'
      PAIR_RE = %r{(#{KV_RE})=(#{KV_RE})}
      def filtered_query_string
        query_string.gsub(PAIR_RE) do |_|
          parameter_filter.filter([[$1, $2]]).first.join("=")
        end
      end

    end
  end
end
