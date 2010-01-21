require 'active_support/core_ext/hash/keys'

module ActionDispatch
  module Http
    module Parameters
      # Returns both GET and POST \parameters in a single hash.
      def parameters
        @env["action_dispatch.request.parameters"] ||= request_parameters.merge(query_parameters).update(path_parameters).with_indifferent_access
      end
      alias :params :parameters

      def path_parameters=(parameters) #:nodoc:
        @env.delete("action_dispatch.request.symbolized_path_parameters")
        @env.delete("action_dispatch.request.parameters")
        @env["action_dispatch.request.path_parameters"] = parameters
      end

      # The same as <tt>path_parameters</tt> with explicitly symbolized keys.
      def symbolized_path_parameters
        @env["action_dispatch.request.symbolized_path_parameters"] ||= path_parameters.symbolize_keys
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

      def filter_parameters
        # TODO: Remove dependency on controller
        if controller = @env['action_controller.instance']
          controller.send(:filter_parameters, params)
        else
          params
        end
      end

      def filter_env
        if controller = @env['action_controller.instance']
          @env.map do |key, value|
            if (key =~ /RAW_POST_DATA/i)
              '[FILTERED]'
            else
              controller.send(:filter_parameters, {key => value}).values[0]
            end
          end
        else
          env
        end
      end

    private
      # Convert nested Hashs to HashWithIndifferentAccess
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