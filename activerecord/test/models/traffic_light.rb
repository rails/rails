# frozen_string_literal: true

class TrafficLight < ActiveRecord::Base
  serialize :state, type: Array
  serialize :long_state, type: Array
end
