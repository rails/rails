require "active_support/dependencies/autoload"

module ActiveSupport
  module Concurrent
    extend ActiveSupport::Autoload

    autoload :Cache
    autoload :LowWriteCache, 'active_support/concurrent/cache'
  end
end