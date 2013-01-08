require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/hash/indifferent_access'

module ActionDispatch
  module Http
    module Parameters
      def initialize(env)
        super
        @symbolized_path_params = nil
      end

      # Returns both GET and POST \parameters in a single hash.
      def parameters
        @env["action_dispatch.request.parameters"] ||= begin
          params = begin
            request_parameters.merge(query_parameters)
          rescue EOFError
            query_parameters.dup
          end
          params.merge!(path_parameters)
          encode_params(params).with_indifferent_access
        end
      end
      alias :params :parameters

      def path_parameters=(parameters) #:nodoc:
        @symbolized_path_params = nil
        @env.delete("action_dispatch.request.parameters")
        @env["action_dispatch.request.path_parameters"] = parameters
      end

      # The same as <tt>path_parameters</tt> with explicitly symbolized keys.
      def symbolized_path_parameters
        @symbolized_path_params ||= path_parameters.symbolize_keys
      end

      # Returns a hash with the \parameters used to form the \path of the request.
      # Returned hash keys are strings:
      #
      #   {'action' => 'my_action', 'controller' => 'my_controller'}
      #
      # See <tt>symbolized_path_parameters</tt> for symbolized keys.
      def path_parameters
        @env["action_dispatch.request.path_parameters"] ||= {}
      end

      def reset_parameters #:nodoc:
        @env.delete("action_dispatch.request.parameters")
      end

    private

      # TODO: Validate that the characters are UTF-8. If they aren't,
      # you'll get a weird error down the road, but our form handling
      # should really prevent that from happening
      def encode_params(params)
        if params.is_a?(String)
          return params.force_encoding("UTF-8").encode!
        elsif !params.is_a?(Hash)
          return params
        end

        params.each do |k, v|
          case v
          when Hash
            encode_params(v)
          when Array
            v.map! {|el| encode_params(el) }
          else
            encode_params(v)
          end
        end
      end

      # Convert nested Hash to ActiveSupport::HashWithIndifferentAccess
      def normalize_parameters(value)
        case value
        when Hash
          h = {}
          value.each { |k, v| h[k] = normalize_parameters(v) }
          h.with_indifferent_access
        when Array
          value.map { |e| normalize_parameters(e) }
        else
          value
        end
      end
    end
  end
end
