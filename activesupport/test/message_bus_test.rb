require 'drb/drb'
require 'drb/acl'
require 'abstract_unit'
require 'active_support/message_bus'

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

  test 'start_server and ServerControlService#stop' do
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

  test 'main and ServerControlService#stop' do
    
    server_pid = fork do
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