module ActionService # :nodoc:
  module Container # :nodoc:
    class ContainerError < ActionService::ActionServiceError # :nodoc:
    end

    def self.append_features(base) # :nodoc:
      super
      base.class_inheritable_option(:web_service_dispatching_mode, :direct)
      base.class_inheritable_option(:web_service_exception_reporting, true)
      base.extend(ClassMethods)
      base.send(:include, ActionService::Container::InstanceMethods)
    end

    module ClassMethods
      # Declares a web service that will provides access to the API of the given
      # +object+. +object+ must be an ActionService::Base derivative.
      #
      # Web service object creation can either be _immediate_, where the object
      # instance is given at class definition time, or _deferred_, where
      # object instantiation is delayed until request time.
      #
      # ==== Immediate web service object example
      #
      #   class ApiController < ApplicationController
      #     web_service_dispatching_mode :delegated
      #
      #     web_service :person, PersonService.new
      #   end
      #
      # For deferred instantiation, a block should be given instead of an
      # object instance. This block will be executed in controller instance
      # context, so it can rely on controller instance variables being present.
      #
      # ==== Deferred web service object example
      #
      #   class ApiController < ApplicationController
      #     web_service_dispatching_mode :delegated
      #
      #     web_service(:person) { PersonService.new(@request.env) }
      #   end
      def web_service(name, object=nil, &block)
        if (object && block_given?) || (object.nil? && block.nil?)
          raise(ContainerError, "either service, or a block must be given")
        end
        name = name.to_sym
        if block_given?
          info = { name => { :block => block } }
        else
          info = { name => { :object => object } }
        end
        write_inheritable_hash("web_services", info)
        call_web_service_definition_callbacks(self, name, info)
      end

      # Whether this service contains a service with the given +name+
      def has_web_service?(name)
        web_services.has_key?(name.to_sym)
      end

      def web_services # :nodoc:
        read_inheritable_attribute("web_services") || {}
      end

      def add_web_service_definition_callback(&block) # :nodoc:
        write_inheritable_array("web_service_definition_callbacks", [block])
      end

      private
        def call_web_service_definition_callbacks(container_class, web_service_name, service_info)
          (read_inheritable_attribute("web_service_definition_callbacks") || []).each do |block|
            block.call(container_class, web_service_name, service_info)
          end
        end
    end

    module InstanceMethods # :nodoc:
      def web_service_object(web_service_name)
        info = self.class.web_services[web_service_name.to_sym]
        unless info
          raise(ContainerError, "no such web service '#{web_service_name}'")
        end
        service = info[:block]
        service ? instance_eval(&service) : info[:object]
      end

      private
        def dispatch_web_service_request(protocol_request)
          case web_service_dispatching_mode
          when :direct
            dispatch_direct_web_service_request(protocol_request)
          when :delegated
            dispatch_delegated_web_service_request(protocol_request)
          else
            raise(ContainerError, "unsupported dispatching mode :#{web_service_dispatching_mode}")
          end
        end

        def dispatch_direct_web_service_request(protocol_request)
          public_method_name = protocol_request.public_method_name
          api = self.class.web_service_api
          method_name = api.api_method_name(public_method_name)
          block = nil
          expects = nil
          if method_name
            signature = api.api_methods[method_name]
            expects = signature[:expects]
            protocol_request.type = Protocol::CheckedMessage
            protocol_request.signature = expects
            protocol_request.return_signature = signature[:returns]
          else
            protocol_request.type = Protocol::UncheckedMessage
            system_methods = self.class.read_inheritable_attribute('default_system_methods') || {}
            protocol = protocol_request.protocol
            block = system_methods[protocol.class]
            unless block
              method_name = api.default_api_method
              unless method_name && respond_to?(method_name)
                raise(ContainerError, "no such method ##{public_method_name}")
              end
            end
          end

          @method_params = protocol_request.unmarshal
          @params ||= {}
          if expects
            (1..@method_params.size).each do |i|
              i -= 1
              if expects[i].is_a?(Hash)
                @params[expects[i].keys.shift.to_s] = @method_params[i]
              else
                @params["param#{i}"] = @method_params[i]
              end
            end
          end

          if respond_to?(:before_action)
            @params['action'] = method_name.to_s
            return protocol_request.marshal(nil) if before_action == false
          end

          perform_invoke = lambda do
            if block
              block.call(public_method_name, self.class, *@method_params)
            else
              send(method_name)
            end
          end
          try_default = true
          result = nil
          catch(:try_default) do
            result = perform_invoke.call
            try_default = false
          end
          if try_default
            method_name = api.default_api_method
            if method_name
              protocol_request.type = Protocol::UncheckedMessage
            else
              raise(ContainerError, "no such method ##{public_method_name}")
            end
            result = perform_invoke.call
          end
          after_action if respond_to?(:after_action)
          protocol_request.marshal(result)
        end

        def dispatch_delegated_web_service_request(protocol_request)
          web_service_name = protocol_request.web_service_name
          service = web_service_object(web_service_name)
          api = service.class.web_service_api
          public_method_name = protocol_request.public_method_name
          method_name = api.api_method_name(public_method_name)

          invocation = ActionService::Invocation::InvocationRequest.new(
            ActionService::Invocation::ConcreteInvocation,
            public_method_name,
            method_name)

          if method_name
            protocol_request.type = Protocol::CheckedMessage
            signature = api.api_methods[method_name]
            protocol_request.signature = signature[:expects]
            protocol_request.return_signature = signature[:returns]
            invocation.params = protocol_request.unmarshal
          else
            protocol_request.type = Protocol::UncheckedMessage
            invocation.type = ActionService::Invocation::VirtualInvocation
            system_methods = self.class.read_inheritable_attribute('default_system_methods') || {}
            protocol = protocol_request.protocol
            block = system_methods[protocol.class]
            if block
              invocation.block = block
              invocation.block_params << service.class
            else
              method_name = api.default_api_method
              if method_name && service.respond_to?(method_name)
                invocation.params = protocol_request.unmarshal
                invocation.method_name = method_name.to_sym
              else
                raise(ContainerError, "no such method /#{web_service_name}##{public_method_name}")
              end
            end
          end

          canceled_reason = nil
          canceled_block = lambda{|r| canceled_reason = r}
          perform_invoke = lambda do
            service.perform_invocation(invocation, &canceled_block)
          end
          try_default = true
          result = nil
          catch(:try_default) do
            result = perform_invoke.call
            try_default = false
          end
          if try_default
            method_name = api.default_api_method
            if method_name
              protocol_request.type = Protocol::UncheckedMessage
              invocation.params = protocol_request.unmarshal
              invocation.method_name = method_name.to_sym
              invocation.type = ActionService::Invocation::UnpublishedConcreteInvocation
            else
              raise(ContainerError, "no such method /#{web_service_name}##{public_method_name}")
            end
            result = perform_invoke.call
          end
          protocol_request.marshal(result)
        end
    end
  end
end
