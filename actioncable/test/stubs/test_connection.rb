require "stubs/user"
require "stubs/test_client"

class TestConnection
  attr_reader :logger, :client, :server, :transmissions

  delegate :pubsub, to: :server
  delegate :identifiers, :current_user, to: :client

  def initialize(user = User.new("lifo"), coder: ActiveSupport::JSON, client_class: TestClient, subscription_adapter: SuccessAdapter)
    @coder = coder
    @logger = ActiveSupport::TaggedLogging.new ActiveSupport::Logger.new(StringIO.new)
    @server = TestServer.new(subscription_adapter: subscription_adapter)

    @client = client_class.new(self, coder: @coder, user: user)

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
