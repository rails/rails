require 'benchmark'

module ActionWebService # :nodoc:
  module Dispatcher # :nodoc:
    class DispatcherError < ActionWebService::ActionWebServiceError # :nodoc:
    end

    def self.append_features(base) # :nodoc:
      super
      base.class_inheritable_option(:web_service_dispatching_mode, :direct)
      base.class_inheritable_option(:web_service_exception_reporting, true)
      base.send(:include, ActionWebService::Dispatcher::InstanceMethods)
    end

    def self.layered_service_name(public_method_name) # :nodoc:
      if public_method_name =~ /^([^\.]+)\.(.*)$/
        $1
      else
        nil
      end
    end

    module InstanceMethods # :nodoc:
      private
        def invoke_web_service_request(protocol_request)
          invocation = web_service_invocation(protocol_request)
          case web_service_dispatching_mode
          when :direct
            web_service_direct_invoke(invocation)
          when :delegated, :layered
            web_service_delegated_invoke(invocation)
          end
        end
      
        def web_service_direct_invoke(invocation)
          @method_params = invocation.method_ordered_params
          arity = method(invocation.api_method_name).arity rescue 0
          if arity < 0 || arity > 0
            return_value = self.__send__(invocation.api_method_name, *@method_params)
          else
            return_value = self.__send__(invocation.api_method_name)
          end
          if invocation.api.has_api_method?(invocation.api_method_name)
            returns = invocation.returns ? invocation.returns[0] : nil
          else
            returns = return_value.class
          end
          invocation.protocol.marshal_response(invocation.public_method_name, return_value, returns)
        end

        def web_service_delegated_invoke(invocation)
          cancellation_reason = nil
          return_value = invocation.service.perform_invocation(invocation.api_method_name, invocation.method_ordered_params) do |x|
            cancellation_reason = x
          end
          if cancellation_reason
            raise(DispatcherError, "request canceled: #{cancellation_reason}")
          end
          returns = invocation.returns ? invocation.returns[0] : nil
          invocation.protocol.marshal_response(invocation.public_method_name, return_value, returns)
        end

        def web_service_invocation(request)
          public_method_name = request.method_name
          invocation = Invocation.new
          invocation.protocol = request.protocol
          invocation.service_name = request.service_name
          if web_service_dispatching_mode == :layered
            if request.method_name =~ /^([^\.]+)\.(.*)$/
              public_method_name = $2
              invocation.service_name = $1
            end
          end
          invocation.public_method_name = public_method_name
          case web_service_dispatching_mode
          when :direct
            invocation.api = self.class.web_service_api
            invocation.service = self
          when :delegated, :layered
            invocation.service = web_service_object(invocation.service_name) rescue nil
            unless invocation.service
              raise(DispatcherError, "service #{invocation.service_name} not available")
            end
            invocation.api = invocation.service.class.web_service_api
          end
          if invocation.api.has_public_api_method?(public_method_name)
            invocation.api_method_name = invocation.api.api_method_name(public_method_name)
          else
            if invocation.api.default_api_method.nil?
              raise(DispatcherError, "no such method '#{public_method_name}' on API #{invocation.api}")
            else
              invocation.api_method_name = invocation.api.default_api_method.to_s.to_sym
            end
          end
          unless invocation.service.respond_to?(invocation.api_method_name)
              raise(DispatcherError, "no such method '#{public_method_name}' on API #{invocation.api} (#{invocation.api_method_name})")
          end
          info = invocation.api.api_methods[invocation.api_method_name]
          invocation.expects = info ? info[:expects] : nil
          invocation.returns = info ? info[:returns] : nil
          if invocation.expects
            i = 0
            invocation.method_ordered_params = request.method_params.map do |param|
              if invocation.protocol.is_a?(Protocol::XmlRpc::XmlRpcProtocol)
                marshaler = invocation.protocol.marshaler
                decoded_param = WS::Encoding::XmlRpcDecodedParam.new(param.info.name, param.value)
                marshaled_param = marshaler.typed_unmarshal(decoded_param, invocation.expects[i]) rescue nil
                param = marshaled_param ? marshaled_param : param
              end
              i += 1
              param.value
            end
            i = 0
            params = []
            invocation.expects.each do |spec|
              type_binding = invocation.protocol.register_signature_type(spec)
              info = WS::ParamInfo.create(spec, type_binding, i)
              params << WS::Param.new(invocation.method_ordered_params[i], info)
              i += 1
            end
            invocation.method_ws_params = params
            invocation.method_named_params = {}
            invocation.method_ws_params.each do |param|
              invocation.method_named_params[param.info.name] = param.value
            end
          else
            invocation.method_ordered_params = []
            invocation.method_named_params = {}
          end
          if invocation.returns
            invocation.returns.each do |spec|
              invocation.protocol.register_signature_type(spec)
            end
          end
          invocation
        end

        class Invocation # :nodoc:
          attr_accessor :protocol
          attr_accessor :service_name
          attr_accessor :api
          attr_accessor :public_method_name
          attr_accessor :api_method_name
          attr_accessor :method_ordered_params
          attr_accessor :method_named_params
          attr_accessor :method_ws_params
          attr_accessor :expects
          attr_accessor :returns
          attr_accessor :service
        end
    end
  end
end
