require 'minitest/mock'

module ServerHelpers
  private

  def initialize_app_for(server, primary_ip = "1.2.3.4")
    server.options[:config].gsub! "/railties/config.ru", "/railties/test/config.ru"
    server.app.config.eager_load = false
    server.app.config.session_store :cookie_store, key: '_Test_session'

    fake_ip = Struct.new :ip_address, :ipv4?
    local_ips = [
      fake_ip.new("::1", false),
      fake_ip.new("127.0.0.1", true),
      fake_ip.new("127.0.0.1", true),
      fake_ip.new("fe80::1%lo0", false),
      fake_ip.new("fe80::1234:5678:9abc:def0%en0", false),
      fake_ip.new(primary_ip, true)
    ]

    Socket.stub :ip_address_list, lambda { local_ips } do
      server.app.initialize!
    end
  end

  # Tear down just enough of the Rails::Application so it can be fully initialized again.
  # This approach allows us to examine how parameters are set after going through the
  # initialization process when running "rails server"
  def teardown_app_for(server)
    # This lets us get past "RuntimeError: Application has been already initialized."
    server.app.instance_variable_set("@initialized", false)
    # Forget about any instances
    server.app.class.instance_variable_set(:@instance, nil)
    # This lets us get to "can't modify frozen array" or past "Expected nil (NilClass) to respond to #include?."
    server.app.remove_instance_variable(:@ran) if server.app.instance_variable_defined?(:@ran)
    # This gets us past "can't modify frozen array"
    server.app.routes_reloader.instance_variable_set(:@paths, [])
  end
end
