require 'swiftcore/evented_mongrel'

module Rack
  module Handler
    class EventedMongrel < Handler::Mongrel
    end
  end
end
