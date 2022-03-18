# frozen_string_literal: true


require "models/traffic_light"

class EncryptedTrafficLight < TrafficLight
  encrypts :state
end

class EncryptedTrafficLightWithStoreState < TrafficLight
  store :state, accessors: %i[ color ]
  encrypts :state
end
