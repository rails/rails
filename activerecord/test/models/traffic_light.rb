class TrafficLight < ActiveRecord::Base
  serialize :state, Array
end
