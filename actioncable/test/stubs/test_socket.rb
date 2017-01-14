require "stubs/user"
require "stubs/test_connection"

class TestSocket
  attr_reader :logger, :connection, :server, :transmissions

  delegate :pubsub, to: :server
  delegate :identifiers, :current_user, to: :connection

  def initialize(user = User.new("lifo"), coder: ActiveSupport::JSON, connection_class: TestConnection, subscription_adapter: SuccessAdapter)
    @coder = coder
    @logger = ActiveSupport::TaggedLogging.new ActiveSupport::Logger.new(StringIO.new)
    @server = TestServer.new(subscription_adapter: subscription_adapter)

    @connection = connection_class.new(self, coder: @coder, user: user)

    @transmissions = []
  end

  def transmit(websocket_message)
    @transmissions << websocket_message
  end

  def last_transmission
    decode @transmissions.last if @transmissions.any?
  end

  def decode(websocket_message)
    @coder.decode websocket_message
  end
end
