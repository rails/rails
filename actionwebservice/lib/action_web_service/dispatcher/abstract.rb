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

    module InstanceMethods # :nodoc:
      private
        def dispatch_web_service_request(action_pack_request)
          protocol_request = protocol_response = nil
          bm = Benchmark.measure do
            protocol_request = probe_request_protocol(action_pack_request)
            protocol_response = dispatch_protocol_request(protocol_request)
          end
          [protocol_request, protocol_response, bm.real, nil]
        rescue Exception => e
          protocol_response = prepare_exception_response(protocol_request, e) 
          [protocol_request, prepare_exception_response(protocol_request, e), nil, e]
        end
      
        def dispatch_protocol_request(protocol_request)
          case web_service_dispatching_mode
          when :direct
            dispatch_direct_request(protocol_request)
          when :delegated
            dispatch_delegated_request(protocol_request)
          else
            raise(ContainerError, "unsupported dispatching mode :#{web_service_dispatching_mode}")
          end
        end

        def dispatch_direct_request(protocol_request)
          request = prepare_dispatch_request(protocol_request)
          return_value = direct_invoke(request)
          protocol_request.marshal(return_value)
        end

        def dispatch_delegated_request(protocol_request)
          request = prepare_dispatch_request(protocol_request)
          return_value = delegated_invoke(request)
          protocol_request.marshal(return_value)
        end

        def direct_invoke(request)
          return nil unless before_direct_invoke(request)
          return_value = send(request.method_name)
          after_direct_invoke(request)
          return_value
        end

        def before_direct_invoke(request)
          @method_params = request.params
        end

        def after_direct_invoke(request)
        end

        def delegated_invoke(request)
          cancellation_reason = nil
          web_service = request.web_service
          return_value = web_service.perform_invocation(request.method_name, request.params) do |x|
            cancellation_reason = x
          end
          if cancellation_reason
            raise(DispatcherError, "request canceled: #{cancellation_reason}")
          end
          return_value
        end

        def prepare_dispatch_request(protocol_request)
          api = method_name = web_service_name = web_service = params = nil
          public_method_name = protocol_request.public_method_name
          case web_service_dispatching_mode
          when :direct
            api = self.class.web_service_api
          when :delegated
            web_service_name = protocol_request.web_service_name
            web_service = web_service_object(web_service_name)
            api = web_service.class.web_service_api
          end
          method_name  = api.api_method_name(public_method_name)
          signature = nil
          if method_name
            signature = api.api_methods[method_name]
            protocol_request.type = Protocol::CheckedMessage
            protocol_request.signature = signature[:expects]
            protocol_request.return_signature = signature[:returns]
          else
            method_name = api.default_api_method
            if method_name
              protocol_request.type = Protocol::UncheckedMessage
            else
              raise(DispatcherError, "no such method #{web_service_name}##{public_method_name}")
            end
          end
          params = protocol_request.unmarshal
          DispatchRequest.new(
            :api                => api,
            :public_method_name => public_method_name,
            :method_name        => method_name,
            :signature          => signature,
            :web_service_name   => web_service_name,
            :web_service        => web_service,
            :params             => params)
        end

        def prepare_exception_response(protocol_request, exception)
          if protocol_request && exception
            case web_service_dispatching_mode
            when :direct
              if web_service_exception_reporting
                return protocol_request.protocol.marshal_exception(exception)
              end
            when :delegated
              web_service = web_service_object(protocol_request.web_service_name)
              if web_service && web_service.class.web_service_exception_reporting
                return protocol_request.protocol.marshal_exception(exception)
              end
            end
          else
            protocol_request.protocol.marshal_exception(RuntimeError.new("missing protocol request or exception"))
          end
        rescue Exception
          nil
        end

        class DispatchRequest
          attr :api
          attr :public_method_name
          attr :method_name
          attr :signature
          attr :web_service_name
          attr :web_service
          attr :params

          def initialize(values={})
            values.each{|k,v| instance_variable_set("@#{k.to_s}", v)}
          end
        end
    end
  end
end
