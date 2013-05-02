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
          params.with_indifferent_access
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

      # Convert nested Hash to HashWithIndifferentAccess
      # and UTF-8 encode both keys and values in nested Hash.
      #
      # TODO: Validate that the characters are UTF-8. If they aren't,
      # you'll get a weird error down the road, but our form handling
      # should really prevent that from happening
      def normalize_encode_params(params)
        if params.is_a?(String)
          return params.force_encoding(Encoding::UTF_8).encode!
        elsif !params.is_a?(Hash)
          return params
        end

        new_hash = {}
        params.each do |k, v|
          new_key = k.is_a?(String) ? k.dup.force_encoding(Encoding::UTF_8).encode! : k
          new_hash[new_key] =
            case v
            when Hash
              normalize_encode_params(v)
            when Array
              v.map! {|el| normalize_encode_params(el) }
            else
              normalize_encode_params(v)
            end
        end
        new_hash.with_indifferent_access
      end
    end
  end
end
