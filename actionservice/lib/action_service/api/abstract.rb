module ActionService # :nodoc:
  module API # :nodoc:
    class APIError < ActionService::ActionServiceError # :nodoc:
    end

    def self.append_features(base) # :nodoc:
      super
      base.extend(ClassMethods)
    end

    module ClassMethods
      # Attaches ActionService API +definition+ to the calling class.
      #
      # If +definition+ is not an ActionService::API::Base derivative class
      # object, it may be a symbol or a string, in which case a file named
      # <tt>definition_api.rb</tt> will be expected to exist in the load path,
      # containing an API definition class named <tt>DefinitionAPI</tt> or
      # <tt>DefinitionApi</tt>.
      #
      # Action Controllers can have a default associated API, removing the need
      # to call this method if you follow the Action Service naming conventions.
      #
      # A controller with a class name of GoogleSearchController will
      # implicitly load <tt>app/apis/google_search_api.rb</tt>, and expect the
      # API definition class to be named <tt>GoogleSearchAPI</tt> or
      # <tt>GoogleSearchApi</tt>.
      #
      # ==== Service class example
      #
      #   class MyService < ActionService::Base
      #     service_api MyAPI
      #   end
      #
      #   class MyAPI < ActionService::API::Base
      #     ...
      #   end
      #
      # ==== Controller class example
      #
      #   class MyController < ActionController::Base
      #     service_api MyAPI
      #   end
      #
      #   class MyAPI < ActionService::API::Base
      #     ...
      #   end
      def service_api(definition=nil)
        if definition.nil?
          read_inheritable_attribute("service_api")
        else
          if definition.is_a?(Symbol)
            raise(APIError, "symbols can only be used for #service_api inside of a controller")
          end
          unless definition.respond_to?(:ancestors) && definition.ancestors.include?(Base)
            raise(APIError, "#{definition.to_s} is not a valid API definition")
          end
          write_inheritable_attribute("service_api", definition)
          call_service_api_callbacks(self, definition)
        end
      end

      def add_service_api_callback(&block) # :nodoc:
        write_inheritable_array("service_api_callbacks", [block])
      end

      private
        def call_service_api_callbacks(container_class, definition)
          (read_inheritable_attribute("service_api_callbacks") || []).each do |block|
            block.call(container_class, definition)
          end
        end
    end

    # A service API class specifies the methods that will be available for
    # invocation for an API. It also contains metadata such as the method type
    # signature hints.
    #
    # It is not intended to be instantiated.
    #
    # It is attached to service implementation classes like ActionService::Base
    # and ActionController::Base derivatives with ClassMethods#service_api.
    class Base
      # Whether to transform API method names into camel-cased
      # names 
      class_inheritable_option :inflect_names, true

      # If present, the name of a method to call when the remote caller
      # tried to call a nonexistent method. Semantically equivalent to
      # +method_missing+.
      class_inheritable_option :default_api_method

      # Disallow instantiation
      private_class_method :new, :allocate
      
      class << self
        include ActionService::Signature

        # API methods have a +name+, which must be the Ruby method name to use when
        # performing the invocation on the service object.
        #
        # The type signature hints for the method input parameters and return value
        # can by specified in +options+.
        #
        # A signature hint is an array of one or more parameter type specifiers. 
        # A type specifier can be one of the following:
        #
        # * A symbol or string of representing one of the Action Service base types.
        #   See ActionService::Signature for a canonical list of the base types.
        # * The Class object of the parameter type
        # * A single-element Array containing one of the two preceding items. This
        #   will cause Action Service to treat the parameter at that position
        #   as an array containing only values of the given type.
        # * A Hash containing as key the name of the parameter, and as value
        #   one of the three preceding items
        # 
        # If no method input parameter or method return value hints are given,
        # the method is assumed to take no parameters and return no values of
        # interest, and any values that are received by the server will be
        # discarded and ignored.
        #
        # Valid options:
        # [<tt>:expects</tt>]             Signature hint for the method input parameters
        # [<tt>:returns</tt>]             Signature hint for the method return value
        # [<tt>:expects_and_returns</tt>] Signature hint for both input parameters and return value
        def api_method(name, options={})
          validate_options([:expects, :returns, :expects_and_returns], options.keys)
          if options[:expects_and_returns]
            expects = options[:expects_and_returns]
            returns = options[:expects_and_returns]
          else
            expects = options[:expects]
            returns = options[:returns]
          end
          expects = canonical_signature(expects) if expects
          returns = canonical_signature(returns) if returns
          if expects && Object.const_defined?('ActiveRecord')
            expects.each do |param|
              klass = signature_parameter_class(param)
              klass = klass[0] if klass.is_a?(Array)
              if klass.ancestors.include?(ActiveRecord::Base)
                raise(ActionServiceError, "ActiveRecord model classes not allowed in :expects")
              end
            end
          end
          name = name.to_sym
          public_name = public_api_method_name(name)
          info = { :expects => expects, :returns => returns }
          write_inheritable_hash("api_methods", name => info)
          write_inheritable_hash("api_public_method_names", public_name => name)
        end

        # Whether the given method name is a service method on this API
        def has_api_method?(name)
          api_methods.has_key?(name)
        end
  
        # Whether the given public method name has a corresponding service method
        # on this API
        def has_public_api_method?(public_name)
          api_public_method_names.has_key?(public_name)
        end
  
        # The corresponding public method name for the given service method name
        def public_api_method_name(name)
          if inflect_names
            name.to_s.camelize
          else
            name.to_s
          end
        end
  
        # The corresponding service method name for the given public method name
        def api_method_name(public_name)
          api_public_method_names[public_name]
        end
  
        # A Hash containing all service methods on this API, and their
        # associated metadata.
        def api_methods
          read_inheritable_attribute("api_methods") || {}
        end
  
        private
          def api_public_method_names
            read_inheritable_attribute("api_public_method_names") || {}
          end
  
          def validate_options(valid_option_keys, supplied_option_keys)
            unknown_option_keys = supplied_option_keys - valid_option_keys
            unless unknown_option_keys.empty?
              raise(ActionServiceError, "Unknown options: #{unknown_option_keys}")
            end
          end

      end
    end
  end
end
