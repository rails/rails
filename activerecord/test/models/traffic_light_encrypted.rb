# frozen_string_literal: true


require "models/traffic_light"

class EncryptedTrafficLight < ActiveRecord::Base
  self.table_name = "traffic_lights"

  encrypts :state
  serialize :state, type: Array
  serialize :long_state, type: Array
end

class EncryptedTrafficLightWithStoreState < ActiveRecord::Base
  self.table_name = "traffic_lights"

  encrypts :state
  serialize :state, type: Array
  serialize :long_state, type: Array
  store :state, accessors: %i[ color ], coder: ActiveRecord::Coders::JSON
end
