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
      # provides access to the underlying soap driver
      attr_reader :driver

      # Creates a new web service client using the SOAP RPC protocol.
      #
      # +api+ must be an ActionWebService::API::Base derivative, and
      # +endpoint_uri+ must point at the relevant URL to which protocol requests
      # will be sent with HTTP POST.
      #
      # Valid options:
      # [<tt>:namespace</tt>]    If the remote server has used a custom namespace to
      #                          declare its custom types, you can specify it here. This would
      #                          be the namespace declared with a [WebService(Namespace = "http://namespace")] attribute
      #                          in .NET, for example.
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
        @namespace = options[:namespace] || 'urn:ActionWebService'
        @driver_options = options[:driver_options] || {}
        @protocol = ActionWebService::Protocol::Soap::SoapProtocol.new @namespace
        @soap_action_base = options[:soap_action_base]
        @soap_action_base ||= URI.parse(endpoint_uri).path
        @driver = create_soap_rpc_driver(api, endpoint_uri)
        @driver_options.each do |name, value|
          @driver.options[name.to_s] = value
        end
      end

      protected
        def perform_invocation(method_name, args)
          method = @api.api_methods[method_name.to_sym]
          args = method.cast_expects(args.dup) rescue args
          return_value = @driver.send(method_name, *args)
          method.cast_returns(return_value.dup) rescue return_value
        end

        def soap_action(method_name)
          "#{@soap_action_base}/#{method_name}"
        end

      private
        def create_soap_rpc_driver(api, endpoint_uri)
          @protocol.register_api(api)
          driver = SoapDriver.new(endpoint_uri, nil)
          driver.mapping_registry = @protocol.marshaler.registry
          api.api_methods.each do |name, method|
            qname = XSD::QName.new(@namespace, method.public_name)
            action = soap_action(method.public_name)
            expects = method.expects
            returns = method.returns
            param_def = []
            if expects
              expects.each do |type|
                type_binding = @protocol.marshaler.lookup_type(type)
                if SOAP::Version >= "1.5.5"
                  param_def << ['in', type.name.to_s, [type_binding.type.type_class.to_s]]
                else
                  param_def << ['in', type.name, type_binding.mapping]
                end
              end
            end
            if returns
              type_binding = @protocol.marshaler.lookup_type(returns[0])
              if SOAP::Version >= "1.5.5"
                param_def << ['retval', 'return', [type_binding.type.type_class.to_s]]
              else
                param_def << ['retval', 'return', type_binding.mapping]
              end
            end
            driver.add_method(qname, action, method.name.to_s, param_def)
          end
          driver
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
