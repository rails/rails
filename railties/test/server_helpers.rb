require 'minitest/mock'

module ServerHelpers
private

  # Capture the earliest starting state of server.app.config
  @@original_options ||= Rails::Railtie::Configuration.class_variable_get(:@@options).deep_dup

  def build_server_with_ips(host_ips = ["192.168.0.10"])
    # Make sure any cached version of options are gone
    GC.start
    sleep 0.1

    # Revert server.app.config back to its original state
    Rails::Railtie::Configuration.class_variable_set(:@@options, @@original_options.deep_dup)

    server = Rails::Server.new
    server.options[:config].gsub! "/railties/config.ru", "/railties/test/config.ru"
    # Quiet the "config.eager_load is set to nil" warning
    server.app.config.eager_load = false

    fake_ip = Struct.new :ip_address, :ipv4?
    local_ips = [
      fake_ip.new("::1", false),
      fake_ip.new("127.0.0.1", true),
      fake_ip.new("fe80::1%lo0", false),
      fake_ip.new("fe80::1234:5678:9abc:def0%en0", false)
    ]
    host_ips.each { |ip| local_ips << fake_ip.new(ip, true) }

    Socket.stub :ip_address_list, lambda { local_ips } do
      server.app.initialize!
    end
    server
  end

  def run_with_custom_args(args, &block)
    original_args = ARGV.dup
    ARGV.replace args
    yield
  ensure
    ARGV.replace original_args
  end

  # Tear down just enough of the Rails::Application so it can be fully initialized again.
  # This approach allows us to examine how parameters are set after going through the
  # initialization process when running "rails server"
  def teardown_app_for(server)
    # This lets us get past "RuntimeError: Application has been already initialized."
    server.app.instance_variable_set("@initialized", false)
    # Forget about the server instance
    server.app.class.instance_variable_set(:@instance, nil)
    # This lets us get past "Expected nil (NilClass) to respond to #include?."
    server.app.remove_instance_variable(:@ran) if server.app.instance_variable_defined?(:@ran)
    # This gets us past "can't modify frozen array"
    server.app.routes_reloader.instance_variable_set(:@paths, [])
  end
end
