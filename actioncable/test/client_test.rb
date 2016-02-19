require 'test_helper'
require 'concurrent'

require 'active_support/core_ext/hash/indifferent_access'
require 'pathname'

require 'faye/websocket'
require 'json'

class ClientTest < ActionCable::TestCase
  WAIT_WHEN_EXPECTING_EVENT = 3
  WAIT_WHEN_NOT_EXPECTING_EVENT = 0.2

  def setup
    ActionCable.instance_variable_set(:@server, nil)
    server = ActionCable.server
    server.config.logger = Logger.new(StringIO.new).tap { |l| l.level = Logger::UNKNOWN }

    server.config.cable = { adapter: 'async' }.with_indifferent_access

    # and now the "real" setup for our test:
    server.config.disable_request_forgery_protection = true
    server.config.channel_paths = [ File.expand_path('client/echo_channel.rb', __dir__) ]

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
    server.add_tcp_listener '127.0.0.1', port
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
        hash = JSON.parse(event.data)
        if hash['identifier'] == '_ping'
          @pings += 1
        else
          @messages << hash
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

    def send_message(hash)
      @ws.send(JSON.dump(hash))
    end

    def close
      sleep WAIT_WHEN_NOT_EXPECTING_EVENT

      unless @messages.empty?
        raise "#{@messages.size} messages unprocessed"
      end

      @ws.close
      @closed.wait(WAIT_WHEN_EXPECTING_EVENT)
    end
  end

  def faye_client(port)
    SyncClient.new(port)
  end

  def test_single_client
    with_puma_server do |port|
      c = faye_client(port)
      c.send_message command: 'subscribe', identifier: JSON.dump(channel: 'EchoChannel')
      assert_equal({"identifier"=>"{\"channel\":\"EchoChannel\"}", "type"=>"confirm_subscription"}, c.read_message)
      c.send_message command: 'message', identifier: JSON.dump(channel: 'EchoChannel'), data: JSON.dump(action: 'ding', message: 'hello')
      assert_equal({"identifier"=>"{\"channel\":\"EchoChannel\"}", "message"=>{"dong"=>"hello"}}, c.read_message)
      c.close
    end
  end

  def test_interacting_clients
    with_puma_server do |port|
      clients = 10.times.map { faye_client(port) }

      barrier_1 = Concurrent::CyclicBarrier.new(clients.size)
      barrier_2 = Concurrent::CyclicBarrier.new(clients.size)

      clients.map {|c| Concurrent::Future.execute {
        c.send_message command: 'subscribe', identifier: JSON.dump(channel: 'EchoChannel')
        assert_equal({"identifier"=>'{"channel":"EchoChannel"}', "type"=>"confirm_subscription"}, c.read_message)
        c.send_message command: 'message', identifier: JSON.dump(channel: 'EchoChannel'), data: JSON.dump(action: 'ding', message: 'hello')
        assert_equal({"identifier"=>'{"channel":"EchoChannel"}', "message"=>{"dong"=>"hello"}}, c.read_message)
        barrier_1.wait WAIT_WHEN_EXPECTING_EVENT
        c.send_message command: 'message', identifier: JSON.dump(channel: 'EchoChannel'), data: JSON.dump(action: 'bulk', message: 'hello')
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
        c.send_message command: 'subscribe', identifier: JSON.dump(channel: 'EchoChannel')
        assert_equal({"identifier"=>'{"channel":"EchoChannel"}', "type"=>"confirm_subscription"}, c.read_message)
        c.send_message command: 'message', identifier: JSON.dump(channel: 'EchoChannel'), data: JSON.dump(action: 'ding', message: 'hello')
        assert_equal({"identifier"=>'{"channel":"EchoChannel"}', "message"=>{"dong"=>"hello"}}, c.read_message)
      } }.each(&:wait!)

      clients.map {|c| Concurrent::Future.execute { c.close } }.each(&:wait!)
    end
  end

  def test_disappearing_client
    with_puma_server do |port|
      c = faye_client(port)
      c.send_message command: 'subscribe', identifier: JSON.dump(channel: 'EchoChannel')
      assert_equal({"identifier"=>"{\"channel\":\"EchoChannel\"}", "type"=>"confirm_subscription"}, c.read_message)
      c.send_message command: 'message', identifier: JSON.dump(channel: 'EchoChannel'), data: JSON.dump(action: 'delay', message: 'hello')
      c.close # disappear before write

      c = faye_client(port)
      c.send_message command: 'subscribe', identifier: JSON.dump(channel: 'EchoChannel')
      assert_equal({"identifier"=>"{\"channel\":\"EchoChannel\"}", "type"=>"confirm_subscription"}, c.read_message)
      c.send_message command: 'message', identifier: JSON.dump(channel: 'EchoChannel'), data: JSON.dump(action: 'ding', message: 'hello')
      assert_equal({"identifier"=>'{"channel":"EchoChannel"}', "message"=>{"dong"=>"hello"}}, c.read_message)
      c.close # disappear before read
    end
  end

  def test_unsubscribe_client
    with_puma_server do |port|
      app = ActionCable.server
      identifier = JSON.dump(channel: 'EchoChannel')

      c = faye_client(port)
      c.send_message command: 'subscribe', identifier: identifier
      assert_equal({"identifier"=>"{\"channel\":\"EchoChannel\"}", "type"=>"confirm_subscription"}, c.read_message)
      assert_equal(1, app.connections.count)
      assert(app.remote_connections.where(identifier: identifier))

      channel = app.connections.first.subscriptions.send(:subscriptions).first[1]
      channel.expects(:unsubscribed)
      c.close
      sleep 0.1 # Data takes a moment to process

      # All data is removed: No more connection or subscription information!
      assert_equal(0, app.connections.count)
    end
  end
end
