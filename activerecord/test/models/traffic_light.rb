class TrafficLight < ApplicationRecord
  serialize :state, Array
  serialize :long_state, Array
end
