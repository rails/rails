require 'stubs/user'

class TestConnection
  attr_reader :identifiers, :logger, :current_user, :server, :transmissions

  def initialize(user = User.new("lifo"))
    @identifiers = [ :current_user ]

    @current_user = user
    @logger = ActiveSupport::TaggedLogging.new ActiveSupport::Logger.new(StringIO.new)
    @server = TestServer.new
    @transmissions = []
  end

  def pubsub
    SuccessAdapter.new(server)
  end

  def transmit(data)
    @transmissions << data
  end

  def last_transmission
    @transmissions.last
  end
end
