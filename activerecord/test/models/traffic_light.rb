class TrafficLight < ApplicationModel
  serialize :state, Array
  serialize :long_state, Array
end
