# frozen_string_literal: true

require "active_support/core_ext/hash/indifferent_access"

module ActionDispatch
  class Request
    module Utils # :nodoc:
      class << self
        attr_accessor :perform_deep_munge
      end
      @perform_deep_munge = true

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
            raise Rack::Utils::InvalidParameterError, "Invalid encoding for parameter: #{params.scrub}"
          end
        end
      end

      def self.set_binary_encoding(request, params, controller, action)
        CustomParamEncoder.encode(request, params, controller, action)
      end

      class ParamEncoder # :nodoc:
        # Convert nested Hash to HashWithIndifferentAccess.
        def self.normalize_encode_params(params)
          case params
          when Array
            handle_array params
          when Hash
            if params.has_key?(:tempfile)
              ActionDispatch::Http::UploadedFile.new(params)
            else
              params.transform_values do |val|
                normalize_encode_params(val)
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

      # Remove nils from the params hash.
      class NoNilParamEncoder < ParamEncoder # :nodoc:
        def self.handle_array(params)
          list = super
          list.compact!
          list
        end
      end

      class CustomParamEncoder # :nodoc:
        def self.encode(request, params, controller, action)
          return params unless controller && controller.valid_encoding? && encoding_template = action_encoding_template(request, controller, action)
          params.except(:controller, :action).each do |key, value|
            ActionDispatch::Request::Utils.each_param_value(value) do |param|
              if encoding_template[key.to_s]
                param.force_encoding(encoding_template[key.to_s])
              end
            end
          end
          params
        end

        def self.action_encoding_template(request, controller, action) # :nodoc:
          request.controller_class_for(controller).action_encoding_template(action)
        rescue MissingController
          nil
        end
      end
    end
  end
end
