require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/deprecation'

module ActionDispatch
  module Http
    module Parameters
      module Strings #:nodoc:
        ACTION_DISPATCH_REQUEST_PARAMETERS = 'action_dispatch.request.parameters'.freeze
        ACTION_DISPATCH_REQUEST_PATH_PARAMETERS = 'action_dispatch.request.path_parameters'.freeze
      end
      private_constant :Strings

      # Returns both GET and POST \parameters in a single hash.
      def parameters
        @env[Strings::ACTION_DISPATCH_REQUEST_PARAMETERS] ||= begin
          params = begin
            request_parameters.merge(query_parameters)
          rescue EOFError
            query_parameters.dup
          end
          params.merge!(path_parameters)
        end
      end
      alias :params :parameters

      def path_parameters=(parameters) #:nodoc:
        @env.delete(Strings::ACTION_DISPATCH_REQUEST_PARAMETERS)
        @env[Strings::ACTION_DISPATCH_REQUEST_PATH_PARAMETERS] = parameters
      end

      def symbolized_path_parameters
        ActiveSupport::Deprecation.warn(
          "`symbolized_path_parameters` is deprecated. Please use `path_parameters`"
        )
        path_parameters
      end

      # Returns a hash with the \parameters used to form the \path of the request.
      # Returned hash keys are strings:
      #
      #   {'action' => 'my_action', 'controller' => 'my_controller'}
      def path_parameters
        @env[Strings::ACTION_DISPATCH_REQUEST_PATH_PARAMETERS] ||= {}
      end

    private

      # Convert nested Hash to HashWithIndifferentAccess.
      #
      def normalize_encode_params(params)
        case params
        when Hash
          if params.has_key?(:tempfile)
            UploadedFile.new(params)
          else
            params.each_with_object({}) do |(key, val), new_hash|
              new_hash[key] = if val.is_a?(Array)
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
    end
  end
end
