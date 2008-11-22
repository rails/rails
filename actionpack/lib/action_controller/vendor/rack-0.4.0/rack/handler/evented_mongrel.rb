require 'swiftcore/evented_mongrel'

module Rack
  module Handler
    class EventedMongrel < Mongrel
    end
  end
end
