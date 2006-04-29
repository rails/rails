module ActionWebService # :nodoc:
  module Container # :nodoc:
    module Delegated # :nodoc:
      class ContainerError < ActionWebServiceError # :nodoc:
      end
  
      def self.included(base) # :nodoc:
        base.extend(ClassMethods)
        base.send(:include, ActionWebService::Container::Delegated::InstanceMethods)
      end
  
      module ClassMethods
        # Declares a web service that will provide access to the API of the given
        # +object+. +object+ must be an ActionWebService::Base derivative.
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
        #     web_service(:person) { PersonService.new(request.env) }
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
          service ? self.instance_eval(&service) : info[:object]
        end
      end
    end
  end
end
