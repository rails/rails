module ActionWebService # :nodoc:
  module API # :nodoc:
    class CastingError < ActionWebService::ActionWebServiceError
    end

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

      # Whether to allow ActiveRecord::Base models in <tt>:expects</tt>.
      # The default is +false+, you should be aware of the security implications
      # of allowing this, and ensure that you don't allow remote callers to
      # easily overwrite data they should not have access to.
      class_inheritable_option :allow_active_record_expects, false

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
              if klass.ancestors.include?(ActiveRecord::Base) && !allow_active_record_expects
                raise(ActionWebServiceError, "ActiveRecord model classes not allowed in :expects")
              end
            end
          end
          name = name.to_sym
          public_name = public_api_method_name(name)
          method = Method.new(name, public_name, expects, returns)
          write_inheritable_hash("api_methods", name => method)
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

        # The Method instance for the given public API method name, if any
        def public_api_method_instance(public_method_name)
          api_method_instance(api_method_name(public_method_name))
        end

        # The Method instance for the given API method name, if any
        def api_method_instance(method_name)
          api_methods[method_name]
        end

        # The Method instance for the default API method, if any
        def default_api_method_instance
          return nil unless name = default_api_method
          instance = read_inheritable_attribute("default_api_method_instance")
          if instance && instance.name == name
            return instance
          end
          instance = Method.new(name, public_api_method_name(name), nil, nil)
          write_inheritable_attribute("default_api_method_instance", instance)
          instance
        end

        # Creates a dummy API Method instance for the given public method name
        def dummy_public_api_method_instance(public_method_name)
          Method.new(public_method_name.underscore.to_sym, public_method_name, nil, nil)
        end

        # Creates a dummy API Method instance for the given method name
        def dummy_api_method_instance(method_name)
          Method.new(method_name, public_api_method_name(method_name), nil, nil)
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

    # Represents an API method and its associated metadata, and provides functionality
    # to assist in commonly performed API method tasks.
    class Method
      attr :name
      attr :public_name
      attr :expects
      attr :returns

      def initialize(name, public_name, expects, returns)
        @name = name
        @public_name = public_name
        @expects = expects
        @returns = returns
      end
      
      # The list of parameter names for this method
      def param_names
        return [] unless @expects
        i = 0
        @expects.map{ |spec| param_name(spec, i += 1) }
      end

      # The name for the given parameter
      def param_name(spec, i=1)
        spec.is_a?(Hash) ? spec.keys.first.to_s : "p#{i}"
      end

      # The type of the parameter declared in +spec+. Is either
      # the Class of the parameter, or its canonical name (if its a
      # base type). Typed array specifications will return the type of
      # their elements.
      def param_type(spec)
        spec = spec.values.first if spec.is_a?(Hash)
        param_type = spec.is_a?(Array) ? spec[0] : spec
        WS::BaseTypes::class_to_type_name(param_type) rescue param_type
      end

      # The Class of the parameter declared in +spec+.
      def param_class(spec)
        type = param_type(spec)
        type.is_a?(Symbol) ? WS::BaseTypes.type_name_to_class(type) : type
      end

      # Registers all types known to this method with the given marshaler
      def register_types(marshaler)
        @expects.each{ |x| marshaler.register_type(x) } if @expects
        @returns.each{ |x| marshaler.register_type(x) } if @returns
      end

      # Encodes an RPC call for this method. Casting is performed if
      # the <tt>:strict</tt> option is given.
      def encode_rpc_call(marshaler, encoder, params, options={})
        name = options[:method_name] || @public_name
        expects = @expects || []
        returns = @returns || []
        (expects + returns).each { |spec| marshaler.register_type spec }
        (0..(params.length-1)).each do |i|
          spec = expects[i] || params[i].class
          type_binding = marshaler.lookup_type(spec)
          param_info = WS::ParamInfo.create(spec, type_binding, i)
          if options[:strict]
            value = marshaler.cast_outbound_recursive(params[i], spec)
          else
            value = params[i]
          end
          param = WS::Param.new(value, param_info)
          params[i] = marshaler.marshal(param)
        end
        encoder.encode_rpc_call(name, params)
      end

      # Encodes an RPC response for this method. Casting is performed if
      # the <tt>:strict</tt> option is given.
      def encode_rpc_response(marshaler, encoder, return_value, options={})
        if !return_value.nil? && @returns
          return_type = @returns[0]
          type_binding = marshaler.register_type(return_type)
          param_info = WS::ParamInfo.create(return_type, type_binding, 0)
          if options[:strict]
            return_value = marshaler.cast_inbound_recursive(return_value, return_type)
          end
          return_value = marshaler.marshal(WS::Param.new(return_value, param_info))
        else
          return_value = nil
        end
        encoder.encode_rpc_response(response_name(encoder), return_value)
      end

      # Casts a set of WS::Param values into the appropriate
      # Ruby values
      def cast_expects_ws2ruby(marshaler, params)
        return [] if @expects.nil?
        i = 0
        @expects.map do |spec|
          value = marshaler.cast_inbound_recursive(params[i].value, spec)
          i += 1
          value
        end
      end
      
      # Casts a set of Ruby values into the expected Ruby values
      def cast_expects(marshaler, params)
        return [] if @expects.nil?
        i = 0
        @expects.map do |spec|
          value = marshaler.cast_outbound_recursive(params[i], spec)
          i += 1
          value
        end
      end

      # Cast a Ruby return value into the expected Ruby value
      def cast_returns(marshaler, return_value)
        return nil if @returns.nil?
        marshaler.cast_inbound_recursive(return_value, @returns[0])
      end

      private
        def response_name(encoder)
          encoder.is_a?(WS::Encoding::SoapRpcEncoding) ? (@public_name + "Response") : @public_name
        end
    end
  end
end
