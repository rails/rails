# frozen_string_literal: true


require "models/traffic_light"

class EncryptedTrafficLight < TrafficLight
  encrypts :state
end
