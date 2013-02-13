require 'drb/drb'
require 'drb/acl'
require 'drb/drb'
require 'singleton'
require 'rinda/ring'
require 'rinda/tuplespace'

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
      @uri_to_set = nil 

      def start_server(options = {})
        acl = extract_acl(options)

        DRb.install_acl(acl)
        DRb.start_service(@uri_to_set, ServiceFacory.instance) # what if call second time?

        controller = ServerControlService.instance
        controller.server = self
      end

      def stop_server
        DRb.stop_service
      end

      def wait_server
        DRb.thread.join
      end

      def uri?
        return DRb.uri
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
        @uri_to_set = nil
        @uri_to_set = _uri.dup if _uri
      end

      #used only for test
      def get_server_uri
        @uri_to_set.dup
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

      def send_message(message)
        #TODO send msg using SSE
        puts "[##{Process.ppid}]now push data to browser, data: \"#{message}\""
      end
    end

    # DiscoverableServer is a DRb server with auto discovery ablility
    # You can find it in the local network through a Rinda client
    class DiscoverableServer < DRbServer
      def start_server(options = {})
        super(options)

        startup_rinda_server
      end

      def stop_server
        # Because we DRb server and Rinda server are running in the 
        # same process, a call to DRb.stop_service will enventually
        # stop both DRb server and Rinda server
        p '=========='
        p Thread.list
        DRb.stop_service
        p '==============='
        p Thread.list
        p '================'
      end

      def startup_rinda_server
        # DRb.start_service already called in super.start_server
        Rinda::RingServer.new Rinda::TupleSpace.new
      end
    end

    # MessageServer is used to control the message server
    # You can call start_server to start a new server(both InProc and StandAlone)
    # You can then send_message to the server directly if the server is 
    # configured as *InRroc*. 
    # You must call find_server before send_message is called, f the server 
    # is configured as *StandAlone*
    # 
    # The process that calls start_server is considered to be the owner
    # of the message server. For process that is not owner of this server must
    # call find_server to get access to the server. (don't call start_server)
    #
    # stop_server can be called in both owner process and guest process
    class MessageServer
      include Singleton
      @is_owner_process = false
      @is_in_proc_server = false
      @server_uri = nil

      # Public: Start the message server
      #
      # options  - A hash to config the server. Has following options:
      #            :deploy - The deploy type, can be :InProc(default) or :StandAlone
      #            :acl - The access control list for DRb server.Defaults to noly allow local access
      #
      # Examples
      #   To use a InProc server:
      #     server = MeesageServer.instance
      #     server.start_server :deploy => :InProc
      #     server.send_message msg_obj
      #     server.stop_server
      #
      #   To use a StandAlone server:
      #     server = MeesageServer.instance
      #     server.start_server :deploy => :StandAlone
      #     sleep(1)  # wait for server to startup
      #     server.find_server
      #     server.send_message msg_obj
      #     server.stop_server
      #
      #   To find a server for guest process:
      #     server = MeesageServer.instance
      #     server.find_server #this assumes server has started
      #     server.send_message msg_obj
      #     server.stop_server
      #
      def start_server(options = {})
        @is_owner_process = true

        method = extract_deploy_method(options)
        if method == :InProc
          @is_in_proc_server = true
          start_local_server(options)
        else #method == :StandAlone
          @is_in_proc_server = false
          start_remote_server(options)
        end
      end

      # Public: Stop message server
      def stop_server
        raise RuntimeError, 'call find_server first' unless @server_uri

        services = DRbObject.new_with_uri @server_uri

        controller = services.get_server_control_service
        controller.stop_server
      end

      # Public: Find a message server
      def find_server
        # we assume that guest process and owner process without a InProc server
        # have to start DRb service. so we call it first
        if !(@is_owner_process && @is_in_proc_server)
          DRb.start_service 
        end
        ring_server = Rinda::RingFinger.primary
        @server_uri = ring_server.__drburi
      end

      # Public: Duplicate some text an arbitrary number of times.
      #
      # message  - An arbitrary object to carry message
      #
      def send_message(message)
        raise RuntimeError, 'call find_server first' unless @server_uri

        services = DRbObject.new_with_uri @server_uri
        
        msg = services.get_message_service
        msg.send_message(message)
      end

      def extract_deploy_method(options = {})
        default_method = :InProc
        return default_method unless options
        return default_method unless options[:deploy]

        method = options[:deploy];
        return default_method unless [:InProc, :StandAlone].include? method

        method
      end

      def wait_in_proc_server
        if @_local_server_thread == nil
          raise RuntimeError, "wait_in_proc_server can be called when your current process host a server"
        end
        @_local_server_thread.join
      end

      def start_local_server(options = {})
        server = ActiveSupport::MessageBus::DiscoverableServer.new

        server.start_server(options)
        @server_uri = server.uri?
        @_local_server_thread = DRb.thread
      end

      def start_remote_server(options = {})
        pid = fork do
          server = ActiveSupport::MessageBus::DiscoverableServer.new

          server.start_server
          server.wait_server
        end
      end

    end
  end
end