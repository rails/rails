# frozen_string_literal: true

require "test_helper"
require "stubs/test_server"

class ActionCable::Connection::CallbacksTest < ActionCable::TestCase
  class Connection < ActionCable::Connection::Base
    identified_by :context

    attr_reader :commands_counter

    before_command do
      throw :abort unless context.nil?
    end

    around_command :set_current_context
    after_command :increment_commands_counter

    def initialize(*)
      super
      @commands_counter = 0
    end

    private
      def set_current_context
        self.context = request.params["context"]
        yield
      ensure
        self.context = nil
      end

      def increment_commands_counter
        @commands_counter += 1
      end
  end

  class ChatChannel < ActionCable::Channel::Base
    class << self
      attr_accessor :words_spoken, :subscribed_count
    end

    self.words_spoken = []
    self.subscribed_count = 0

    def subscribed
      self.class.subscribed_count += 1
    end

    def speak(data)
      self.class.words_spoken << { data: data, context: context }
    end
  end

  setup do
    @server = TestServer.new
    @env = Rack::MockRequest.env_for "/test", "HTTP_HOST" => "localhost", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket"
    @connection = Connection.new(@server, @env)
    @identifier = { channel: "ActionCable::Connection::CallbacksTest::ChatChannel" }.to_json
  end

  attr_reader :server, :env, :connection, :identifier

  test "before and after callbacks" do
    result = assert_difference -> { ChatChannel.subscribed_count }, +1 do
      assert_difference -> { connection.commands_counter }, +1 do
        connection.handle_channel_command({ "identifier" => identifier, "command" => "subscribe" })
      end
    end
    assert result
  end

  test "before callback halts" do
    connection.context = "non_null"
    result = assert_no_difference -> { ChatChannel.subscribed_count } do
      connection.handle_channel_command({ "identifier" => identifier, "command" => "subscribe" })
    end
    assert_not result
  end

  test "around_command callback" do
    env["QUERY_STRING"] = "context=test"
    connection = Connection.new(server, env)

    assert_difference -> { ChatChannel.words_spoken.size }, +1 do
      # We need to add subscriptions first
      connection.handle_channel_command({
        "identifier" => identifier,
        "command" => "subscribe"
      })
      connection.handle_channel_command({
        "identifier" => identifier,
        "command" => "message",
        "data" =>  { "action" => "speak", "message" => "hello" }.to_json
      })
    end

    message = ChatChannel.words_spoken.last
    assert_equal({ data: { "action" => "speak", "message" => "hello" }, context: "test" }, message)
  end
end
