# frozen_string_literal: true

require "test_helper"
require "concurrent"

require "websocket-client-simple"
require "json"

require "active_support/hash_with_indifferent_access"

# test with iodine if platform allows
begin
  require "iodine"
rescue LoadError
  nil
end

####
# 😷 Warning suppression 😷
WebSocket::Frame::Handler::Handler03.prepend Module.new {
  def initialize(*)
    @application_data_buffer = nil
    super
  end
}

WebSocket::Frame::Data.prepend Module.new {
  def initialize(*)
    @masking_key = nil
    super
  end
}
#
####

class ClientTest < ActionCable::TestCase
  WAIT_WHEN_EXPECTING_EVENT = 2
  WAIT_WHEN_NOT_EXPECTING_EVENT = 0.5

  class EchoChannel < ActionCable::Channel::Base
    def subscribed
      stream_from "global"
    end

    def unsubscribed
      "Goodbye from EchoChannel!"
    end

    def ding(data)
      transmit(dong: data["message"])
    end

    def delay(data)
      sleep 1
      transmit(dong: data["message"])
    end

    def bulk(data)
      ActionCable.server.broadcast "global", wide: data["message"]
    end
  end

  def setup
    ActionCable.instance_variable_set(:@server, nil)
    server = ActionCable.server
    server.config.logger = Logger.new(StringIO.new).tap { |l| l.level = Logger::UNKNOWN }

    server.config.cable = ActiveSupport::HashWithIndifferentAccess.new(adapter: "async")

    # and now the "real" setup for our test:
    server.config.disable_request_forgery_protection = true
  end

  def with_puma_server(rack_app = ActionCable.server, port = 3099, block)
    server = ::Puma::Server.new(rack_app, ::Puma::Events.strings)
    server.add_tcp_listener "127.0.0.1", port
    server.min_threads = 1
    server.max_threads = 4

    thread = server.run

    begin
      block.call(port)

    ensure
      server.stop

      begin
        thread.join

      rescue IOError
        # Work around https://bugs.ruby-lang.org/issues/13405
        #
        # Puma's sometimes raising while shutting down, when it closes
        # its internal pipe. We can safely ignore that, but we do need
        # to do the step skipped by the exception:
        server.binder.close

      rescue RuntimeError => ex
        # Work around https://bugs.ruby-lang.org/issues/13239
        raise unless ex.message =~ /can't modify frozen IOError/

        # Handle this as if it were the IOError: do the same as above.
        server.binder.close
      end
    end
  end

  if defined?(::Iodine)
    def with_iodine_server(rack_app = ActionCable.server, port = 3099, block)
      begin
        ::Iodine.listen2http(app: rack_app, port: port.to_s, address: "127.0.0.1")
        ::Iodine.workers = 1 # don't cluster the test
        ::Iodine.threads = 1 # one for the server another for the task
        t = Thread.new { ::Iodine.start }
        block.call(port)
      rescue
        nil
      ensure
        ::Iodine.stop
        t.join
      end
    end
  else
    def with_iodine_server(rack_app = ActionCable.server, port = 3099, block)
      skip "Iodine testing skipped, unsupported?."
      puts "Iodine testing skipped, unsupported?."
    end
  end

  def with_cable_server(rack_app = ActionCable.server, port = 3099, &block)
    puts "Testing with Puma"
    with_puma_server(rack_app, port, block)
    puts "Testing with Iodine"
    with_iodine_server(rack_app, port, block)
  end

  class SyncClient
    attr_reader :pings

    def initialize(port)
      messages = @messages = Queue.new
      closed = @closed = Concurrent::Event.new
      has_messages = @has_messages = Concurrent::Semaphore.new(0)
      pings = @pings = Concurrent::AtomicFixnum.new(0)

      open = Concurrent::Promise.new

      @ws = WebSocket::Client::Simple.connect("ws://127.0.0.1:#{port}/") do |ws|
        ws.on(:error) do |event|
          event = RuntimeError.new(event.message) unless event.is_a?(Exception)

          if open.pending?
            open.fail(event)
          else
            messages << event
            has_messages.release
          end
        end

        ws.on(:open) do |event|
          open.set(true)
        end

        ws.on(:message) do |event|
          if event.type == :close
            closed.set
          else
            message = JSON.parse(event.data)
            if message["type"] == "ping"
              pings.increment
            else
              messages << message
              has_messages.release
            end
          end
        end

        ws.on(:close) do |event|
          closed.set
        end
      end

      open.wait!(WAIT_WHEN_EXPECTING_EVENT)
    end

    def read_message
      @has_messages.try_acquire(1, WAIT_WHEN_EXPECTING_EVENT)

      msg = @messages.pop(true)
      raise msg if msg.is_a?(Exception)

      msg
    end

    def read_messages(expected_size = 0)
      list = []
      loop do
        if @has_messages.try_acquire(1, list.size < expected_size ? WAIT_WHEN_EXPECTING_EVENT : WAIT_WHEN_NOT_EXPECTING_EVENT)
          msg = @messages.pop(true)
          raise msg if msg.is_a?(Exception)

          list << msg
        else
          break
        end
      end
      list
    end

    def send_message(message)
      @ws.send(JSON.generate(message))
    end

    def close
      sleep WAIT_WHEN_NOT_EXPECTING_EVENT

      unless @messages.empty?
        raise "#{@messages.size} messages unprocessed"
      end

      @ws.close
      wait_for_close
    end

    def wait_for_close
      @closed.wait(WAIT_WHEN_EXPECTING_EVENT)
    end

    def closed?
      @closed.set?
    end
  end

  def websocket_client(port)
    SyncClient.new(port)
  end

  def concurrently(enum)
    enum.map { |*x| Concurrent::Future.execute { yield(*x) } }.map(&:value!)
  end

  def test_single_client
    with_cable_server do |port|
      c = websocket_client(port)
      assert_equal({ "type" => "welcome" }, c.read_message)  # pop the first welcome message off the stack
      c.send_message command: "subscribe", identifier: JSON.generate(channel: "ClientTest::EchoChannel")
      assert_equal({ "identifier" => "{\"channel\":\"ClientTest::EchoChannel\"}", "type" => "confirm_subscription" }, c.read_message)
      c.send_message command: "message", identifier: JSON.generate(channel: "ClientTest::EchoChannel"), data: JSON.generate(action: "ding", message: "hello")
      assert_equal({ "identifier" => "{\"channel\":\"ClientTest::EchoChannel\"}", "message" => { "dong" => "hello" } }, c.read_message)
      c.close
    end
  end

  def test_interacting_clients
    with_cable_server do |port|
      clients = concurrently(10.times) { websocket_client(port) }

      barrier_1 = Concurrent::CyclicBarrier.new(clients.size)
      barrier_2 = Concurrent::CyclicBarrier.new(clients.size)

      concurrently(clients) do |c|
        assert_equal({ "type" => "welcome" }, c.read_message)  # pop the first welcome message off the stack
        c.send_message command: "subscribe", identifier: JSON.generate(channel: "ClientTest::EchoChannel")
        assert_equal({ "identifier" => '{"channel":"ClientTest::EchoChannel"}', "type" => "confirm_subscription" }, c.read_message)
        c.send_message command: "message", identifier: JSON.generate(channel: "ClientTest::EchoChannel"), data: JSON.generate(action: "ding", message: "hello")
        assert_equal({ "identifier" => '{"channel":"ClientTest::EchoChannel"}', "message" => { "dong" => "hello" } }, c.read_message)
        barrier_1.wait WAIT_WHEN_EXPECTING_EVENT
        c.send_message command: "message", identifier: JSON.generate(channel: "ClientTest::EchoChannel"), data: JSON.generate(action: "bulk", message: "hello")
        barrier_2.wait WAIT_WHEN_EXPECTING_EVENT
        assert_equal clients.size, c.read_messages(clients.size).size
      end

      concurrently(clients, &:close)
    end
  end

  def test_many_clients
    with_cable_server do |port|
      clients = concurrently(100.times) { websocket_client(port) }

      concurrently(clients) do |c|
        assert_equal({ "type" => "welcome" }, c.read_message)  # pop the first welcome message off the stack
        c.send_message command: "subscribe", identifier: JSON.generate(channel: "ClientTest::EchoChannel")
        assert_equal({ "identifier" => '{"channel":"ClientTest::EchoChannel"}', "type" => "confirm_subscription" }, c.read_message)
        c.send_message command: "message", identifier: JSON.generate(channel: "ClientTest::EchoChannel"), data: JSON.generate(action: "ding", message: "hello")
        assert_equal({ "identifier" => '{"channel":"ClientTest::EchoChannel"}', "message" => { "dong" => "hello" } }, c.read_message)
      end

      concurrently(clients, &:close)
    end
  end

  def test_disappearing_client
    with_cable_server do |port|
      c = websocket_client(port)
      assert_equal({ "type" => "welcome" }, c.read_message)  # pop the first welcome message off the stack
      c.send_message command: "subscribe", identifier: JSON.generate(channel: "ClientTest::EchoChannel")
      assert_equal({ "identifier" => "{\"channel\":\"ClientTest::EchoChannel\"}", "type" => "confirm_subscription" }, c.read_message)
      c.send_message command: "message", identifier: JSON.generate(channel: "ClientTest::EchoChannel"), data: JSON.generate(action: "delay", message: "hello")
      c.close # disappear before write

      c = websocket_client(port)
      assert_equal({ "type" => "welcome" }, c.read_message) # pop the first welcome message off the stack
      c.send_message command: "subscribe", identifier: JSON.generate(channel: "ClientTest::EchoChannel")
      assert_equal({ "identifier" => "{\"channel\":\"ClientTest::EchoChannel\"}", "type" => "confirm_subscription" }, c.read_message)
      c.send_message command: "message", identifier: JSON.generate(channel: "ClientTest::EchoChannel"), data: JSON.generate(action: "ding", message: "hello")
      assert_equal({ "identifier" => '{"channel":"ClientTest::EchoChannel"}', "message" => { "dong" => "hello" } }, c.read_message)
      c.close # disappear before read
    end
  end

  def test_unsubscribe_client
    with_cable_server do |port|
      app = ActionCable.server
      identifier = JSON.generate(channel: "ClientTest::EchoChannel")

      c = websocket_client(port)
      assert_equal({ "type" => "welcome" }, c.read_message)
      c.send_message command: "subscribe", identifier: identifier
      assert_equal({ "identifier" => "{\"channel\":\"ClientTest::EchoChannel\"}", "type" => "confirm_subscription" }, c.read_message)
      assert_equal(1, app.connections.count)
      assert(app.remote_connections.where(identifier: identifier))

      subscriptions = app.connections.first.subscriptions.send(:subscriptions)
      assert_not_equal 0, subscriptions.size, "Missing EchoChannel subscription"
      channel = subscriptions.first[1]
      assert_called(channel, :unsubscribed) do
        c.close
        sleep 0.1 # Data takes a moment to process
      end

      # All data is removed: No more connection or subscription information!
      assert_equal(0, app.connections.count)
    end
  end

  def test_server_restart
    with_cable_server do |port|
      c = websocket_client(port)
      assert_equal({ "type" => "welcome" }, c.read_message)
      c.send_message command: "subscribe", identifier: JSON.generate(channel: "ClientTest::EchoChannel")
      assert_equal({ "identifier" => "{\"channel\":\"ClientTest::EchoChannel\"}", "type" => "confirm_subscription" }, c.read_message)

      ActionCable.server.restart
      c.wait_for_close
      assert_predicate c, :closed?
    end
  end
end
