require 'drb/drb'
require 'drb/acl'
require 'rinda/ring'
require 'abstract_unit'

ENV['N'] = "1"  #ensure test case not run simultaneously

class DRbServerTest < ActiveSupport::TestCase
  URI = "druby://localhost:8788";

  test 'set_server_uri' do
    server = ActiveSupport::MessageBus::DRbServer.new
    server.set_server_uri "rubyonrails.org"
    assert_equal "rubyonrails.org", server.get_server_uri

    server.set_server_uri nil
    assert_nil server.get_server_uri

    server.set_server_uri "rubyonrails.org"
    assert_equal "rubyonrails.org", server.get_server_uri
  end

  test 'extract_acl_list with valid acl list' do
    ACL_LIST = %w(
        deny all
        allow localhost
        allow 127.0.0.1
      )
    options = {
      acl: ACL_LIST,
      uri: "rubyonrails.org",
      dummy: "123"
    }

    server = ActiveSupport::MessageBus::DRbServer.new
    acl = server.extract_acl_list options
   
    assert_equal ACL_LIST, acl
  end

  test 'extract_acl_list with invalid acl list' do
    options = {
      uri: "rubyonrails.org",
      dummy: "123"
    }

    server = ActiveSupport::MessageBus::DRbServer.new
    acl = server.extract_acl_list options

    assert_equal ActiveSupport::MessageBus::DRbServer::DEFAULT_ACL, acl

    acl = server.extract_acl_list nil
    assert_equal ActiveSupport::MessageBus::DRbServer::DEFAULT_ACL, acl
  end

  test 'start_server and stop_server' do
    server = ActiveSupport::MessageBus::DRbServer.new
    server.set_server_uri(URI)

    # start server
    server.start_server

    # ensure the DRb server is startup
    remote_server = DRbObject.new_with_uri(URI)

    assert_respond_to remote_server, :get_server_control_service
    assert_respond_to remote_server, :get_message_service

    # stop server
    server.stop_server

    # ensure the DRb server has shutdown
    assert_raise(DRb::DRbConnError){
      remote_server.get_server_control_service
    }


    # ensure we can restart the server
    # and exception will throw when we trying to bind to the same port
    server.start_server
    assert_raise(Errno::EADDRINUSE)do
      server.start_server
    end
    server.stop_server
  end

  test 'start_server and ServerControlService#stop in same process' do
    server = ActiveSupport::MessageBus::DRbServer.new
    server.set_server_uri(URI)

    server.start_server

    remote_server = DRbObject.new_with_uri(URI)
    control = remote_server.get_server_control_service

    assert_not_nil control
    assert_respond_to control, :stop_server

    # stop server
    control.stop_server
    assert_raise(DRb::DRbConnError){
      remote_server.get_server_control_service
    }
  end

  test 'start_server and ServerControlService#stop in different processes' do
    
    fork do
      # URI is captured into sub process!
      server = ActiveSupport::MessageBus::DRbServer.new
      
      server.set_server_uri(URI);
      server.start_server
      server.wait_server
    end

    # Waiting for subprocess to estanblish
    sleep(1)

    remote_server = DRbObject.new_with_uri(URI)
    control = remote_server.get_server_control_service

    assert_not_nil control
    assert_respond_to control, :stop_server

    # stop server
    control.stop_server
    # Waiting for subprocess to estanblish
    sleep(1)
    assert_raise(DRb::DRbConnError){
      remote_server.get_server_control_service
    }
  end
end

# The DiscoverableServer and MessageServer depends on Rinda
# While Rinda can be only initialized properly per one process
# So we put every test case into an extra process so that they 
# don't disturb each other.
#
# We use ActiveSupport::Testing::Isolation to run every testcase 
# in sepatate procss.
#
class DiscoverableServerTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  test 'DiscoverableServer can be auto discoverd' do
    begin
      fork do
        server = ActiveSupport::MessageBus::DiscoverableServer.new
        #server.set_server_uri(URI); need not to know uri in advance
        server.start_server
        server.wait_server
      end

      sleep(1)  
      DRb.start_service
      finger = Rinda::RingFinger.new nil, ActiveSupport::MessageBus::DiscoverableServer::DEFAULT_PORT
      ring_server = finger.lookup_ring_any
      services = DRbObject.new_with_uri ring_server.__drburi
      controller = services.get_server_control_service
    ensure
      controller.stop_server
      sleep(1)
    end
  end
end


class  MessageServerTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  test 'start a InProc server' do
    begin
      server = ActiveSupport::MessageBus::MessageServer.instance
      server.start_server :deploy => :InProc
      server.send_message "David Wang"
    ensure
      server.stop_server
    end
  end

  test 'start a StandAlone server' do
    begin
      server = ActiveSupport::MessageBus::MessageServer.instance
      server.start_server :deploy => :StandAlone

      sleep(1) # waiting server to start
      server.find_server
      server.send_message "David Wang"
    ensure
      server.stop_server
      sleep(1)
    end
  end

  test 'find a InProc server in guest process' do
    begin
      fork do
        server = ActiveSupport::MessageBus::MessageServer.instance
        server.start_server :deploy => :InProc
        server.wait_in_proc_server
      end

      sleep(1) 
      remote_server = ActiveSupport::MessageBus::MessageServer.instance
      remote_server.find_server
      remote_server.send_message "David Wang"
    ensure
      remote_server.stop_server
      sleep(1)
    end
  end

  test 'find a StandAlone server in guest process' do
    begin
      fork do
        # This owner process do nothing but start a stand alone server
        server = ActiveSupport::MessageBus::MessageServer.instance
        server.start_server :deploy => :StandAlone
      end

      sleep(1) 
      remote_server = ActiveSupport::MessageBus::MessageServer.instance
      remote_server.find_server
      remote_server.send_message "David Wang"
    ensure
      remote_server.stop_server
      sleep(1)
    end
  end
end
