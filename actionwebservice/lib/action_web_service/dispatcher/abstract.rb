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
          arity = method(invocation.api_method.name).arity rescue 0
          if arity < 0 || arity > 0
            return_value = self.__send__(invocation.api_method.name, *@method_params)
          else
            return_value = self.__send__(invocation.api_method.name)
          end
          if invocation.api.has_api_method?(invocation.api_method.name)
            api_method = invocation.api_method
          else
            api_method = invocation.api_method.dup
            api_method.instance_eval{ @returns = [ return_value.class ] }
          end
          invocation.protocol.marshal_response(api_method, return_value)
        end

        def web_service_delegated_invoke(invocation)
          cancellation_reason = nil
          return_value = invocation.service.perform_invocation(invocation.api_method.name, invocation.method_ordered_params) do |x|
            cancellation_reason = x
          end
          if cancellation_reason
            raise(DispatcherError, "request canceled: #{cancellation_reason}")
          end
          invocation.protocol.marshal_response(invocation.api_method, return_value)
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
          unless invocation.service.respond_to?(invocation.api_method.name)
              raise(DispatcherError, "no such method '#{public_method_name}' on API #{invocation.api} (#{invocation.api_method.name})")
          end
          request.api_method = invocation.api_method
          begin
            invocation.method_ordered_params = invocation.api_method.cast_expects_ws2ruby(request.protocol.marshaler, request.method_params)
          rescue
            invocation.method_ordered_params = request.method_params.map{ |x| x.value }
          end
          invocation.method_named_params = {}
          invocation.api_method.param_names.inject(0) do |m, n|
            invocation.method_named_params[n] = invocation.method_ordered_params[m]
            m + 1
          end
          invocation
        end

        class Invocation # :nodoc:
          attr_accessor :protocol
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
