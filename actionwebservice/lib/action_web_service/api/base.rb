module ActionWebService # :nodoc:
  module API # :nodoc:
    # A web service API class specifies the methods that will be available for
    # invocation for an API. It also contains metadata such as the method type
    # signature hints.
    #
    # It is not intended to be instantiated.
    #
    # It is attached to web service implementation classes like
    # ActionWebService::Base and ActionController::Base derivatives by using
    # ClassMethods#web_service_api.
    class Base
      # Whether to transform the public API method names into camel-cased names 
      class_inheritable_option :inflect_names, true

      # If present, the name of a method to call when the remote caller
      # tried to call a nonexistent method. Semantically equivalent to
      # +method_missing+.
      class_inheritable_option :default_api_method

      # Disallow instantiation
      private_class_method :new, :allocate
      
      class << self
        # API methods have a +name+, which must be the Ruby method name to use when
        # performing the invocation on the web service object.
        #
        # The signatures for the method input parameters and return value can
        # by specified in +options+.
        #
        # A signature is an array of one or more parameter specifiers. 
        # A parameter specifier can be one of the following:
        #
        # * A symbol or string of representing one of the Action Web Service base types.
        #   See ActionWebService::Signature for a canonical list of the base types.
        # * The Class object of the parameter type
        # * A single-element Array containing one of the two preceding items. This
        #   will cause Action Web Service to treat the parameter at that position
        #   as an array containing only values of the given type.
        # * A Hash containing as key the name of the parameter, and as value
        #   one of the three preceding items
        # 
        # If no method input parameter or method return value signatures are given,
        # the method is assumed to take no parameters and/or return no values of
        # interest, and any values that are received by the server will be
        # discarded and ignored.
        #
        # Valid options:
        # [<tt>:expects</tt>]             Signature for the method input parameters
        # [<tt>:returns</tt>]             Signature for the method return value
        # [<tt>:expects_and_returns</tt>] Signature for both input parameters and return value
        def api_method(name, options={})
          validate_options([:expects, :returns, :expects_and_returns], options.keys)
          if options[:expects_and_returns]
            expects = options[:expects_and_returns]
            returns = options[:expects_and_returns]
          else
            expects = options[:expects]
            returns = options[:returns]
          end
          expects = canonical_signature(expects)
          returns = canonical_signature(returns)
          if expects
            expects.each do |param|
              klass = WS::BaseTypes.canonical_param_type_class(param)
              klass = klass[0] if klass.is_a?(Array)
              if klass.ancestors.include?(ActiveRecord::Base)
                raise(ActionWebServiceError, "ActiveRecord model classes not allowed in :expects")
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
              raise(ActionWebServiceError, "Unknown options: #{unknown_option_keys}")
            end
          end

          def canonical_signature(signature)
            return nil if signature.nil?
            signature.map{|spec| WS::BaseTypes.canonical_param_type_spec(spec)}
          end
      end
    end
  end
end
