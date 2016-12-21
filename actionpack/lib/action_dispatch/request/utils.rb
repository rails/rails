module ActionDispatch
  class Request
    class Utils # :nodoc:
      mattr_accessor :perform_deep_munge
      self.perform_deep_munge = true

      def self.each_param_value(params, &block)
        case params
        when Array
          params.each { |element| each_param_value(element, &block) }
        when Hash
          params.each_value { |value| each_param_value(value, &block) }
        when String
          block.call params
        end
      end

      def self.normalize_encode_params(params)
        if perform_deep_munge
          NoNilParamEncoder.normalize_encode_params params
        else
          ParamEncoder.normalize_encode_params params
        end
      end

      def self.check_param_encoding(params)
        case params
        when Array
          params.each { |element| check_param_encoding(element) }
        when Hash
          params.each_value { |value| check_param_encoding(value) }
        when String
          unless params.valid_encoding?
            # Raise Rack::Utils::InvalidParameterError for consistency with Rack.
            # ActionDispatch::Request#GET will re-raise as a BadRequest error.
            raise Rack::Utils::InvalidParameterError, "Non UTF-8 value: #{params}"
          end
        end
      end

      class ParamEncoder # :nodoc:
        # Convert nested Hash to HashWithIndifferentAccess.
        #
        def self.normalize_encode_params(params)
          case params
          when Array
            handle_array params
          when Hash
            if params.has_key?(:tempfile)
              ActionDispatch::Http::UploadedFile.new(params)
            else
              params.each_with_object({}) do |(key, val), new_hash|
                new_hash[key] = normalize_encode_params(val)
              end.with_indifferent_access
            end
          else
            params
          end
        end

        def self.handle_array(params)
          params.map! { |el| normalize_encode_params(el) }
        end
      end

      # Remove nils from the params hash
      class NoNilParamEncoder < ParamEncoder # :nodoc:
        def self.handle_array(params)
          list = super
          list.compact!
          list
        end
      end
    end
  end
end
