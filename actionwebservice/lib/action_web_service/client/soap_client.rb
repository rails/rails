require 'soap/rpc/driver'
require 'uri'

module ActionWebService # :nodoc:
  module Client # :nodoc:

    # Implements SOAP client support (using RPC encoding for the messages).
    #
    # ==== Example Usage
    #
    #   class PersonAPI < ActionWebService::API::Base
    #     api_method :find_all, :returns => [[Person]]
    #   end
    #
    #   soap_client = ActionWebService::Client::Soap.new(PersonAPI, "http://...")
    #   persons = soap_client.find_all
    #
    class Soap < Base

      # Creates a new web service client using the SOAP RPC protocol.
      #
      # +api+ must be an ActionWebService::API::Base derivative, and
      # +endpoint_uri+ must point at the relevant URL to which protocol requests
      # will be sent with HTTP POST.
      #
      # Valid options:
      # [<tt>:type_namespace</tt>]    If the remote server has used a custom namespace to
      #                               declare its custom types, you can specify it here
      # [<tt>:method_namespace</tt>]  If the remote server has used a custom namespace to
      #                               declare its methods, you can specify it here
      # [<tt>:driver_options</tt>]    If you want to supply any custom SOAP RPC driver
      #                               options, you can provide them as a Hash here
      #
      # The <tt>:driver_options</tt> option can be used to configure the backend SOAP
      # RPC driver. An example of configuring the SOAP backend to do
      # client-certificate authenticated SSL connections to the server:
      #
      #   opts = {}
      #   opts['protocol.http.ssl_config.verify_mode'] = 'OpenSSL::SSL::VERIFY_PEER'
      #   opts['protocol.http.ssl_config.client_cert'] = client_cert_file_path
      #   opts['protocol.http.ssl_config.client_key'] = client_key_file_path
      #   opts['protocol.http.ssl_config.ca_file'] = ca_cert_file_path
      #   client = ActionWebService::Client::Soap.new(api, 'https://some/service', :driver_options => opts)
      def initialize(api, endpoint_uri, options={})
        super(api, endpoint_uri)
        @type_namespace = options[:type_namespace] || 'urn:ActionWebService'
        @method_namespace = options[:method_namespace] || 'urn:ActionWebService'
        @driver_options = options[:driver_options] || {}
        @marshaler = WS::Marshaling::SoapMarshaler.new @type_namespace
        @encoder = WS::Encoding::SoapRpcEncoding.new @method_namespace
        @soap_action_base = options[:soap_action_base]
        @soap_action_base ||= URI.parse(endpoint_uri).path
        @driver = create_soap_rpc_driver(api, endpoint_uri)
        @driver_options.each do |name, value|
          @driver.options[name.to_s] = value.to_s
        end
      end

      protected
        def perform_invocation(method_name, args)
          @driver.send(method_name, *args)
        end

        def soap_action(method_name)
          "#{@soap_action_base}/#{method_name}"
        end

      private
        def create_soap_rpc_driver(api, endpoint_uri)
          register_api(@marshaler, api)
          driver = SoapDriver.new(endpoint_uri, nil)
          driver.mapping_registry = @marshaler.registry
          api.api_methods.each do |name, info|
            public_name = api.public_api_method_name(name)
            qname = XSD::QName.new(@method_namespace, public_name)
            action = soap_action(public_name)
            expects = info[:expects]
            returns = info[:returns]
            param_def = []
            i = 0
            if expects
              expects.each do |spec|
                param_name = spec.is_a?(Hash) ? spec.keys[0].to_s : "param#{i}"
                type_binding = @marshaler.register_type(spec)
                param_def << ['in', param_name, type_binding.mapping]
                i += 1
              end
            end
            if returns
              type_binding = @marshaler.register_type(returns[0])
              param_def << ['retval', 'return', type_binding.mapping]
            end
            driver.add_method(qname, action, name.to_s, param_def)
          end
          driver
        end

        def register_api(marshaler, api)
          type_bindings = []
          api.api_methods.each do |name, info|
            expects, returns = info[:expects], info[:returns]
            if expects
              expects.each{|type| type_bindings << marshaler.register_type(type)}
            end
            if returns
              returns.each{|type| type_bindings << marshaler.register_type(type)}
            end
          end
          type_bindings
        end

        class SoapDriver < SOAP::RPC::Driver # :nodoc:
          def add_method(qname, soapaction, name, param_def)
            @proxy.add_rpc_method(qname, soapaction, name, param_def)
            add_rpc_method_interface(name, param_def)
          end
        end
    end
  end
end
