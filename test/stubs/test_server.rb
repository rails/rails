require 'ostruct'

class TestServer
  attr_reader :logger, :config

  def initialize
    @logger = ActiveSupport::TaggedLogging.new ActiveSupport::Logger.new(StringIO.new)
    @config = OpenStruct.new(log_tags: [])
  end
end
