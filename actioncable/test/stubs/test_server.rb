require 'ostruct'

class TestServer
  include ActionCable::Server::Connections

  attr_reader :logger, :config

  def initialize
    @logger = ActiveSupport::TaggedLogging.new ActiveSupport::Logger.new(StringIO.new)
    @config = OpenStruct.new(log_tags: [], subscription_adapter: SuccessAdapter)
    @config.use_faye = ENV['FAYE'].present?
    @config.client_socket_class = if @config.use_faye
                                    ActionCable::Connection::FayeClientSocket
                                  else
                                    ActionCable::Connection::ClientSocket
                                  end
  end

  def pubsub
    @config.subscription_adapter.new(self)
  end

  def event_loop
    @event_loop ||= if @config.use_faye
                      ActionCable::Connection::FayeEventLoop.new
                    else
                      ActionCable::Connection::StreamEventLoop.new
                    end
  end

  def worker_pool
    @worker_pool ||= ActionCable::Server::Worker.new(max_size: 5)
  end
end
