# frozen_string_literal: true

class TrafficLight < ActiveRecord::Base
  serialize :state, Array
  serialize :long_state, Array
end
