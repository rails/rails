require 'uri'
require 'xmlrpc/client'

module ActionWebService # :nodoc:
  module Client # :nodoc:

    # Implements XML-RPC client support
    #
    # ==== Example Usage
    #
    #   class BloggerAPI < ActionWebService::API::Base
    #     inflect_names false
    #     api_method :getRecentPosts, :returns => [[Blog::Post]]
    #   end
    #
    #   blog = ActionWebService::Client::XmlRpc.new(BloggerAPI, "http://.../RPC", :handler_name => "blogger")
    #   posts = blog.getRecentPosts
    class XmlRpc < Base

      # Creates a new web service client using the XML-RPC protocol.
      #
      # +api+ must be an ActionWebService::API::Base derivative, and
      # +endpoint_uri+ must point at the relevant URL to which protocol requests
      # will be sent with HTTP POST.
      #
      # Valid options:
      # [<tt>:handler_name</tt>]    If the remote server defines its services inside special
      #                             handler (the Blogger API uses a <tt>"blogger"</tt> handler name for example),
      #                             provide it here, or your method calls will fail
      def initialize(api, endpoint_uri, options={})
        @api = api
        @handler_name = options[:handler_name]
        @client = XMLRPC::Client.new2(endpoint_uri, options[:proxy], options[:timeout])
      end

      protected
        def perform_invocation(method_name, args)
          args = transform_outgoing_method_params(method_name, args)
          ok, return_value = @client.call2(public_name(method_name), *args)
          return transform_return_value(method_name, return_value) if ok
          raise(ClientError, "#{return_value.faultCode}: #{return_value.faultString}")
        end

        def transform_outgoing_method_params(method_name, params)
          info = @api.api_methods[method_name.to_sym]
          signature = info[:expects]
          signature_length = signature.nil?? 0 : signature.length
          if signature_length != params.length
            raise(ProtocolError, "API declares #{public_name(method_name)} to accept " +
                                 "#{signature_length} parameters, but #{params.length} parameters " + 
                                 "were supplied")
          end
          if signature_length > 0
            signature = Protocol::XmlRpc::XmlRpcProtocol.transform_array_types(signature)
            (1..signature.size).each do |i|
              i -= 1
              params[i] = Protocol::XmlRpc::XmlRpcProtocol.ruby_to_xmlrpc(params[i], signature[i])
            end
          end
          params
        end

        def transform_return_value(method_name, return_value)
          info = @api.api_methods[method_name.to_sym]
          return true unless signature = info[:returns]
          signature = Protocol::XmlRpc::XmlRpcProtocol.transform_array_types(signature)
          Protocol::XmlRpc::XmlRpcProtocol.xmlrpc_to_ruby(return_value, signature[0])
        end

        def public_name(method_name)
          public_name = @api.public_api_method_name(method_name)
          @handler_name ? "#{@handler_name}.#{public_name}" : public_name
        end
    end
  end
end
