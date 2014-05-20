require 'active_job/log_subscriber'

module ActiveJob
  module Logging
    mattr_accessor(:logger) { ActiveSupport::Logger.new(STDOUT) }
  end
end
