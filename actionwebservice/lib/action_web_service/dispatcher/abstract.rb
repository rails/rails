require 'benchmark'

module ActionWebService # :nodoc:
  module Dispatcher # :nodoc:
    class DispatcherError < ActionWebService::ActionWebServiceError # :nodoc:
      def initialize(*args)
        super
        set_backtrace(caller)
      end
    end

    def self.included(base) # :nodoc:
      base.class_inheritable_option(:web_service_dispatching_mode, :direct)
      base.class_inheritable_option(:web_service_exception_reporting, true)
      base.send(:include, ActionWebService::Dispatcher::InstanceMethods)
    end

    module InstanceMethods # :nodoc:
      private
        def invoke_web_service_request(protocol_request)
          invocation = web_service_invocation(protocol_request)
          if invocation.is_a?(Array) && protocol_request.protocol.is_a?(Protocol::XmlRpc::XmlRpcProtocol)
            xmlrpc_multicall_invoke(invocation)
          else
            web_service_invoke(invocation)
          end
        end
      
        def web_service_direct_invoke(invocation)
          @method_params = invocation.method_ordered_params
          arity = method(invocation.api_method.name).arity rescue 0
          if arity < 0 || arity > 0
            params = @method_params
          else
            params = []
          end
          web_service_filtered_invoke(invocation, params)
        end

        def web_service_delegated_invoke(invocation)
          web_service_filtered_invoke(invocation, invocation.method_ordered_params)
        end

        def web_service_filtered_invoke(invocation, params)
          cancellation_reason = nil
          return_value = invocation.service.perform_invocation(invocation.api_method.name, params) do |x|
            cancellation_reason = x
          end
          if cancellation_reason
            raise(DispatcherError, "request canceled: #{cancellation_reason}")
          end
          return_value
        end
        
        def web_service_invoke(invocation)
          case web_service_dispatching_mode
          when :direct
            return_value = web_service_direct_invoke(invocation)
          when :delegated, :layered
            return_value = web_service_delegated_invoke(invocation)
          end
          web_service_create_response(invocation.protocol, invocation.protocol_options, invocation.api, invocation.api_method, return_value)
        end
        
        def xmlrpc_multicall_invoke(invocations)
          responses = []
          invocations.each do |invocation|
            if invocation.is_a?(Hash)
              responses << [invocation, nil]
              next
            end
            begin
              case web_service_dispatching_mode
              when :direct
                return_value = web_service_direct_invoke(invocation)
              when :delegated, :layered
                return_value = web_service_delegated_invoke(invocation)
              end
              api_method = invocation.api_method
              if invocation.api.has_api_method?(api_method.name)
                response_type = (api_method.returns ? api_method.returns[0] : nil)
                return_value = api_method.cast_returns(return_value)
              else
                response_type = ActionWebService::SignatureTypes.canonical_signature_entry(return_value.class, 0)
              end
              responses << [return_value, response_type]
            rescue Exception => e
              responses << [{ 'faultCode' => 3, 'faultString' => e.message }, nil]
            end
          end
          invocation = invocations[0]
          invocation.protocol.encode_multicall_response(responses, invocation.protocol_options)
        end

        def web_service_invocation(request, level = 0)
          public_method_name = request.method_name
          invocation = Invocation.new
          invocation.protocol = request.protocol
          invocation.protocol_options = request.protocol_options
          invocation.service_name = request.service_name
          if web_service_dispatching_mode == :layered
            case invocation.protocol
            when Protocol::Soap::SoapProtocol
              soap_action = request.protocol_options[:soap_action]
              if soap_action && soap_action =~ /^\/\w+\/(\w+)\//
                invocation.service_name = $1
              end
            when Protocol::XmlRpc::XmlRpcProtocol
              if request.method_name =~ /^([^\.]+)\.(.*)$/
                public_method_name = $2
                invocation.service_name = $1
              end
            end
          end
          if invocation.protocol.is_a? Protocol::XmlRpc::XmlRpcProtocol
            if public_method_name == 'multicall' && invocation.service_name == 'system'
              if level > 0
                raise(DispatcherError, "Recursive system.multicall invocations not allowed")
              end
              multicall = request.method_params.dup
              unless multicall.is_a?(Array) && multicall[0].is_a?(Array)
                raise(DispatcherError, "Malformed multicall (expected array of Hash elements)")
              end
              multicall = multicall[0]
              return multicall.map do |item|
                raise(DispatcherError, "Multicall elements must be Hash") unless item.is_a?(Hash)
                raise(DispatcherError, "Multicall elements must contain a 'methodName' key") unless item.has_key?('methodName')
                method_name = item['methodName']
                params = item.has_key?('params') ? item['params'] : []
                multicall_request = request.dup
                multicall_request.method_name = method_name
                multicall_request.method_params = params
                begin
                  web_service_invocation(multicall_request, level + 1)
                rescue Exception => e
                  {'faultCode' => 4, 'faultMessage' => e.message}
                end
              end
            end
          end
          case web_service_dispatching_mode
          when :direct
            invocation.api = self.class.web_service_api
            invocation.service = self
          when :delegated, :layered
            invocation.service = web_service_object(invocation.service_name)
            invocation.api = invocation.service.class.web_service_api
          end
          if invocation.api.nil?
            raise(DispatcherError, "no API attached to #{invocation.service.class}")
          end
          invocation.protocol.register_api(invocation.api)
          request.api = invocation.api
          if invocation.api.has_public_api_method?(public_method_name)
            invocation.api_method = invocation.api.public_api_method_instance(public_method_name)
          else
            if invocation.api.default_api_method.nil?
              raise(DispatcherError, "no such method '#{public_method_name}' on API #{invocation.api}")
            else
              invocation.api_method = invocation.api.default_api_method_instance
            end
          end
          if invocation.service.nil?
            raise(DispatcherError, "no service available for service name #{invocation.service_name}")
          end
          unless invocation.service.respond_to?(invocation.api_method.name)
            raise(DispatcherError, "no such method '#{public_method_name}' on API #{invocation.api} (#{invocation.api_method.name})")
          end
          request.api_method = invocation.api_method
          begin
            invocation.method_ordered_params = invocation.api_method.cast_expects(request.method_params.dup)
          rescue
            logger.warn "Casting of method parameters failed" unless logger.nil?
            invocation.method_ordered_params = request.method_params
          end
          request.method_params = invocation.method_ordered_params
          invocation.method_named_params = {}
          invocation.api_method.param_names.inject(0) do |m, n|
            invocation.method_named_params[n] = invocation.method_ordered_params[m]
            m + 1
          end
          invocation
        end

        def web_service_create_response(protocol, protocol_options, api, api_method, return_value)
          if api.has_api_method?(api_method.name)
            return_type = api_method.returns ? api_method.returns[0] : nil
            return_value = api_method.cast_returns(return_value)
          else
            return_type = ActionWebService::SignatureTypes.canonical_signature_entry(return_value.class, 0)
          end
          protocol.encode_response(api_method.public_name + 'Response', return_value, return_type, protocol_options)
        end

        class Invocation # :nodoc:
          attr_accessor :protocol
          attr_accessor :protocol_options
          attr_accessor :service_name
          attr_accessor :api
          attr_accessor :api_method
          attr_accessor :method_ordered_params
          attr_accessor :method_named_params
          attr_accessor :service
        end
    end
  end
end
