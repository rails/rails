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
      def normalize_encode_params(params)
        case params
          when String
            encode_string(params)
          when Hash
          if params.has_key?(:tempfile)
            UploadedFile.new(params)
          else
            params.each_with_object({}) do |(key, val), new_hash|
              if key.is_a?(String)
                new_key = encode_string(key.dup)
              else
                new_key = key
              end
              new_hash[new_key] = if val.is_a?(Array)
                val.map! { |el| normalize_encode_params(el) }
              else
                normalize_encode_params(val)
              end
            end.with_indifferent_access
          end
        else
          params
        end
      end

      def encode_string(params)
        begin
          # try it as UTF-8 directly
          params.force_encoding(Encoding::UTF_8).encode!
        rescue EncodingError
          # Force it to UTF-8, throwing out invalid bits
          params.encode!( 'UTF-8', invalid: :replace, undef: :replace )
        end
      end
    end
  end
end
