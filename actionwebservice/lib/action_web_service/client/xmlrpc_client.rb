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
        @protocol = ActionWebService::Protocol::XmlRpc::XmlRpcProtocol.new
        @client = XMLRPC::Client.new2(endpoint_uri, options[:proxy], options[:timeout])
      end

      protected
        def perform_invocation(method_name, args)
          method = @api.api_methods[method_name.to_sym]
          if method.expects && method.expects.length != args.length
            raise(ArgumentError, "#{method.public_name}: wrong number of arguments (#{args.length} for #{method.expects.length})")
          end
          args = method.cast_expects(args.dup) rescue args
          if method.expects
            method.expects.each_with_index{ |type, i| args[i] = @protocol.value_to_xmlrpc_wire_format(args[i], type) }
          end
          ok, return_value = @client.call2(public_name(method_name), *args)
          return (method.cast_returns(return_value.dup) rescue return_value) if ok
          raise(ClientError, "#{return_value.faultCode}: #{return_value.faultString}")
        end

        def public_name(method_name)
          public_name = @api.public_api_method_name(method_name)
          @handler_name ? "#{@handler_name}.#{public_name}" : public_name
        end
    end
  end
end
