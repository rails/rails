require 'stubs/user'

class TestConnection
  attr_reader :identifiers, :logger, :current_user, :transmissions

  def initialize(user = User.new("lifo"))
    @identifiers = [ :current_user ]

    @current_user = user
    @logger = ActiveSupport::TaggedLogging.new ActiveSupport::Logger.new(StringIO.new)
    @transmissions = []
  end

  def adapter
    SuccessAdapter.new(TestServer.new)
  end

  def transmit(data)
    @transmissions << data
  end

  def last_transmission
    @transmissions.last
  end
end
