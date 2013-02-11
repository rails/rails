require 'drb/drb'
require 'drb/acl'
require 'singleton'


module ActiveSupport

  # MessageBus is a mechanism to push messages from rails server to browser.
  # The usage may be pushing a refresh notification to browser when a source file 
  # modification event is raised, Or pushing some real time debug/performance
  # information to browser.
  #
  # Currently MessageBus use a DRb server to recieve server side messages and push
  # them to the browser using Server Sent Events.
  module MessageBus
    # The DRbServer is intend to run stand alone or in prococess
    # This class is for internal use
    class DRbServer
      DEFAULT_ACL = %w(
        deny all
        allow 127.0.0.1
        allow localhost
      )
      @uri = nil 

      def start_server(options = {})
        acl = extract_acl(options)

        DRb.install_acl(acl)
        DRb.start_service(@uri, ServiceFacory.instance) # what if call second time?

        controller = ServerControlService.instance
        controller.server = self
      end

      def stop_server
        DRb.stop_service
      end

      def wait_server
        DRb.thread.join
      end
      # Main entry when server is deployed as stand alone
      # It only takes a hash literal as parameter, others will be ignored
      def main 
        hash_literal = ARGV[0]
        options = eval(hash_literal)

        set_server_uri(options[:uri])
        start_server(options)
      end
      
      def set_server_uri(_uri)
        @uri = nil
        @uri = _uri.dup if _uri
      end

      #used only for test
      def get_server_uri
        @uri
      end

      def extract_acl(options)
        list = extract_acl_list(options)

        ACL.new(list, ACL::DENY_ALLOW)
      end
      def extract_acl_list(options)
        list = options ? options[:acl] : nil
        list = DEFAULT_ACL.dup unless list

        list
      end
    end


    # The front object for out DRb server
    # It's actually a service factory, and currently it provide 2 service
    class ServiceFacory
      include Singleton

      def get_server_control_service
        ServerControlService.instance
      end

      def get_message_service
        MessageService.new
      end
    end

    # Control the DRb server
    class ServerControlService
      include Singleton
      include DRbUndumped

      attr_accessor :server

      def stop_server
        server.stop_server
      end
    end

    # Send messages to browser through SSEs
    class MessageService
      include DRbUndumped

      def send(name, options = {})
        #TODO send msg using SSE
        puts "we recieve message #{name}, with options=#{options}"
        puts "now push it to browser..."
      end
    end

  end
end