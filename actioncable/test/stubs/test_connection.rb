require 'stubs/user'

class TestConnection
  include ActionCable::Connection::Utils

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
    @transmissions << hash_to_json(data)
  end

  def last_transmission
    @transmissions.last
  end
end
