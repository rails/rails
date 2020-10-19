# frozen_string_literal: true

begin
  require "bundler/inline"
rescue LoadError => e
  $stderr.puts "Bundler version 1.10 or later is required. Please update your Bundler"
  raise e
end

gemfile(true) do
  source "https://rubygems.org"
  git_source(:github) { |repo| "https://github.com/#{repo}.git" }
  gem "rails", github: "rails/rails"
  gem "websocket-client-simple", github: "matthewd/websocket-client-simple", branch: "close-race", require: false
  gem "puma"
end

require "rails"
require "action_view/railtie"
require "action_cable/engine"
require "concurrent"
require "minitest/autorun"
require "websocket-client-simple"

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :id, :token

    def connect
      self.id = SecureRandom.uuid
      self.token = request.params[:token] ||
        request.cookies["token"] ||
        request.headers["X-API-TOKEN"]
      end
  end
end

module ApplicationCable
  class Channel < ActionCable::Channel::Base
  end
end

ActionCable.server.config.cable = { "adapter" => "async" }
ActionCable.server.config.connection_class = -> { ApplicationCable::Connection }

class EchoChannel < ApplicationCable::Channel
  def subscribed
    stream_from "global"
  end

  def unsubscribed
    "Goodbye from EchoChannel!"
  end

  def ding(data)
    transmit({ dong: data["message"] })
  end

  def delay(data)
    sleep 1
    transmit({ dong: data["message"] })
  end

  def bulk(data)
    ActionCable.server.broadcast "global", { wide: data["message"] }
  end
end

class ClientTest < ActionCable::TestCase
  WAIT_WHEN_EXPECTING_EVENT = 2
  WAIT_WHEN_NOT_EXPECTING_EVENT = 0.5

  def setup
    ActionCable.instance_variable_set(:@server, nil)
    server = ActionCable.server
    server.config.logger = Logger.new(StringIO.new).tap { |l| l.level = Logger::UNKNOWN }
    server.config.cable = ActiveSupport::HashWithIndifferentAccess.new(adapter: "async")
    server.config.disable_request_forgery_protection = true
  end

  def with_puma_server(rack_app = ActionCable.server, port = 3099)
    server = ::Puma::Server.new(rack_app, ::Puma::Events.strings)
    server.add_tcp_listener "127.0.0.1", port
    server.min_threads = 1
    server.max_threads = 4

    thread = server.run

    begin
      yield port

    ensure
      server.stop

      begin
        thread.join

      rescue IOError
        server.binder.close

      rescue RuntimeError => ex
        raise unless ex.message.match?(/can't modify frozen IOError/)
        server.binder.close
      end
    end
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

        ws.on(:close) do |_|
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

  def test_single_client
    with_puma_server do |port|
      c = websocket_client(port)
      assert_equal({ "type" => "welcome" }, c.read_message)
      c.send_message command: "subscribe", identifier: JSON.generate(channel: "::EchoChannel")
      assert_equal({ "identifier" => "{\"channel\":\"::EchoChannel\"}", "type" => "confirm_subscription" }, c.read_message)
      c.send_message command: "message", identifier: JSON.generate(channel: "::EchoChannel"), data: JSON.generate(action: "ding", message: "hello")
      assert_equal({ "identifier" => "{\"channel\":\"::EchoChannel\"}", "message" => { "dong" => "hello" } }, c.read_message)
      c.close
    end
  end
end
