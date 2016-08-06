require "test_helper"
require "concurrent"

require "faye/websocket"
require "json"

require "active_support/hash_with_indifferent_access"

class ClientTest < ActionCable::TestCase
  WAIT_WHEN_EXPECTING_EVENT = 8
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
    server.config.use_faye = ENV["FAYE"].present?

    # and now the "real" setup for our test:
    server.config.disable_request_forgery_protection = true

    Thread.new { EventMachine.run } unless EventMachine.reactor_running?
    Thread.pass until EventMachine.reactor_running?

    # faye-websocket is warning-rich
    @previous_verbose, $VERBOSE = $VERBOSE, nil
  end

  def teardown
    $VERBOSE = @previous_verbose
  end

  def with_puma_server(rack_app = ActionCable.server, port = 3099)
    server = ::Puma::Server.new(rack_app, ::Puma::Events.strings)
    server.add_tcp_listener "127.0.0.1", port
    server.min_threads = 1
    server.max_threads = 4

    t = Thread.new { server.run.join }
    yield port

  ensure
    server.stop(true) if server
    t.join if t
  end

  class SyncClient
    attr_reader :pings

    def initialize(port)
      @ws = Faye::WebSocket::Client.new("ws://127.0.0.1:#{port}/")
      @messages = Queue.new
      @closed = Concurrent::Event.new
      @has_messages = Concurrent::Semaphore.new(0)
      @pings = 0

      open = Concurrent::Event.new
      error = nil

      @ws.on(:error) do |event|
        if open.set?
          @messages << RuntimeError.new(event.message)
        else
          error = event.message
          open.set
        end
      end

      @ws.on(:open) do |event|
        open.set
      end

      @ws.on(:message) do |event|
        message = JSON.parse(event.data)
        if message["type"] == "ping"
          @pings += 1
        else
          @messages << message
          @has_messages.release
        end
      end

      @ws.on(:close) do |event|
        @closed.set
      end

      open.wait(WAIT_WHEN_EXPECTING_EVENT)
      raise error if error
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

  def faye_client(port)
    SyncClient.new(port)
  end

  def test_single_client
    with_puma_server do |port|
      c = faye_client(port)
      assert_equal({"type" => "welcome"}, c.read_message)  # pop the first welcome message off the stack
      c.send_message command: "subscribe", identifier: JSON.generate(channel: "ClientTest::EchoChannel")
      assert_equal({"identifier"=>"{\"channel\":\"ClientTest::EchoChannel\"}", "type"=>"confirm_subscription"}, c.read_message)
      c.send_message command: "message", identifier: JSON.generate(channel: "ClientTest::EchoChannel"), data: JSON.generate(action: "ding", message: "hello")
      assert_equal({"identifier"=>"{\"channel\":\"ClientTest::EchoChannel\"}", "message"=>{"dong"=>"hello"}}, c.read_message)
      c.close
    end
  end

  def test_interacting_clients
    with_puma_server do |port|
      clients = 10.times.map { faye_client(port) }

      barrier_1 = Concurrent::CyclicBarrier.new(clients.size)
      barrier_2 = Concurrent::CyclicBarrier.new(clients.size)

      clients.map {|c| Concurrent::Future.execute {
        assert_equal({"type" => "welcome"}, c.read_message)  # pop the first welcome message off the stack
        c.send_message command: "subscribe", identifier: JSON.generate(channel: "ClientTest::EchoChannel")
        assert_equal({"identifier"=>'{"channel":"ClientTest::EchoChannel"}', "type"=>"confirm_subscription"}, c.read_message)
        c.send_message command: "message", identifier: JSON.generate(channel: "ClientTest::EchoChannel"), data: JSON.generate(action: "ding", message: "hello")
        assert_equal({"identifier"=>'{"channel":"ClientTest::EchoChannel"}', "message"=>{"dong"=>"hello"}}, c.read_message)
        barrier_1.wait WAIT_WHEN_EXPECTING_EVENT
        c.send_message command: "message", identifier: JSON.generate(channel: "ClientTest::EchoChannel"), data: JSON.generate(action: "bulk", message: "hello")
        barrier_2.wait WAIT_WHEN_EXPECTING_EVENT
        assert_equal clients.size, c.read_messages(clients.size).size
      } }.each(&:wait!)

      clients.map {|c| Concurrent::Future.execute { c.close } }.each(&:wait!)
    end
  end

  def test_many_clients
    with_puma_server do |port|
      clients = 100.times.map { faye_client(port) }

      clients.map {|c| Concurrent::Future.execute {
        assert_equal({"type" => "welcome"}, c.read_message)  # pop the first welcome message off the stack
        c.send_message command: "subscribe", identifier: JSON.generate(channel: "ClientTest::EchoChannel")
        assert_equal({"identifier"=>'{"channel":"ClientTest::EchoChannel"}', "type"=>"confirm_subscription"}, c.read_message)
        c.send_message command: "message", identifier: JSON.generate(channel: "ClientTest::EchoChannel"), data: JSON.generate(action: "ding", message: "hello")
        assert_equal({"identifier"=>'{"channel":"ClientTest::EchoChannel"}', "message"=>{"dong"=>"hello"}}, c.read_message)
      } }.each(&:wait!)

      clients.map {|c| Concurrent::Future.execute { c.close } }.each(&:wait!)
    end
  end

  def test_disappearing_client
    with_puma_server do |port|
      c = faye_client(port)
      assert_equal({"type" => "welcome"}, c.read_message)  # pop the first welcome message off the stack
      c.send_message command: "subscribe", identifier: JSON.generate(channel: "ClientTest::EchoChannel")
      assert_equal({"identifier"=>"{\"channel\":\"ClientTest::EchoChannel\"}", "type"=>"confirm_subscription"}, c.read_message)
      c.send_message command: "message", identifier: JSON.generate(channel: "ClientTest::EchoChannel"), data: JSON.generate(action: "delay", message: "hello")
      c.close # disappear before write

      c = faye_client(port)
      assert_equal({"type" => "welcome"}, c.read_message) # pop the first welcome message off the stack
      c.send_message command: "subscribe", identifier: JSON.generate(channel: "ClientTest::EchoChannel")
      assert_equal({"identifier"=>"{\"channel\":\"ClientTest::EchoChannel\"}", "type"=>"confirm_subscription"}, c.read_message)
      c.send_message command: "message", identifier: JSON.generate(channel: "ClientTest::EchoChannel"), data: JSON.generate(action: "ding", message: "hello")
      assert_equal({"identifier"=>'{"channel":"ClientTest::EchoChannel"}', "message"=>{"dong"=>"hello"}}, c.read_message)
      c.close # disappear before read
    end
  end

  def test_unsubscribe_client
    with_puma_server do |port|
      app = ActionCable.server
      identifier = JSON.generate(channel: "ClientTest::EchoChannel")

      c = faye_client(port)
      assert_equal({"type" => "welcome"}, c.read_message)
      c.send_message command: "subscribe", identifier: identifier
      assert_equal({"identifier"=>"{\"channel\":\"ClientTest::EchoChannel\"}", "type"=>"confirm_subscription"}, c.read_message)
      assert_equal(1, app.connections.count)
      assert(app.remote_connections.where(identifier: identifier))

      subscriptions = app.connections.first.subscriptions.send(:subscriptions)
      assert_not_equal 0, subscriptions.size, "Missing EchoChannel subscription"
      channel = subscriptions.first[1]
      channel.expects(:unsubscribed)
      c.close
      sleep 0.1 # Data takes a moment to process

      # All data is removed: No more connection or subscription information!
      assert_equal(0, app.connections.count)
    end
  end

  def test_server_restart
    with_puma_server do |port|
      c = faye_client(port)
      assert_equal({"type" => "welcome"}, c.read_message)
      c.send_message command: "subscribe", identifier: JSON.generate(channel: "ClientTest::EchoChannel")
      assert_equal({"identifier"=>"{\"channel\":\"ClientTest::EchoChannel\"}", "type"=>"confirm_subscription"}, c.read_message)

      ActionCable.server.restart
      c.wait_for_close
      assert c.closed?
    end
  end
end
