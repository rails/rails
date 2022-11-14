# frozen_string_literal: true

require "active_support/parameter_filter"

module ActionDispatch
  module Http
    # Allows you to specify sensitive parameters which will be replaced from
    # the request log by looking in the query string of the request and all
    # sub-hashes of the params hash to filter. Filtering only certain sub-keys
    # from a hash is possible by using the dot notation: <tt>"credit_card.number"</tt>.
    # If a block is given, each key and value of the params hash and all
    # sub-hashes are passed to it, where the value or the key can be replaced using
    # <tt>String#replace</tt> or similar methods.
    #
    #   # Replaces values with "[FILTERED]" for keys that match /password/i.
    #   env["action_dispatch.parameter_filter"] = [:password]
    #
    #   # Replaces values with "[FILTERED]" for keys that match /foo|bar/i.
    #   env["action_dispatch.parameter_filter"] = [:foo, "bar"]
    #
    #   # Replaces values for the exact key "pin" and for keys that begin with
    #   # "pin_". Does not match keys that otherwise include "pin" as a
    #   # substring, such as "shipping_id".
    #   env["action_dispatch.parameter_filter"] = [ /\Apin\z/, /\Apin_/ ]
    #
    #   # Replaces the value for :code in `{ credit_card: { code: "xxxx" } }`.
    #   # Does not change `{ file: { code: "xxxx" } }`.
    #   env["action_dispatch.parameter_filter"] = [ "credit_card.code" ]
    #
    #   # Reverses values for keys that match /secret/i.
    #   env["action_dispatch.parameter_filter"] = -> (k, v) do
    #     v.reverse! if k.match?(/secret/i)
    #   end
    module FilterParameters
      ENV_MATCH = [/RAW_POST_DATA/, "rack.request.form_vars"] # :nodoc:
      NULL_PARAM_FILTER = ActiveSupport::ParameterFilter.new # :nodoc:
      NULL_ENV_FILTER   = ActiveSupport::ParameterFilter.new ENV_MATCH # :nodoc:

      def initialize
        super
        @filtered_parameters = nil
        @filtered_env        = nil
        @filtered_path       = nil
        @parameter_filter    = nil
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

      # Returns the +ActiveSupport::ParameterFilter+ object used to filter in this request.
      def parameter_filter
        @parameter_filter ||= if has_header?("action_dispatch.parameter_filter")
          parameter_filter_for get_header("action_dispatch.parameter_filter")
        else
          NULL_PARAM_FILTER
        end
      end

    private
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
