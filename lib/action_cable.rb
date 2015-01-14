require 'cramp'
require 'active_support'
require 'active_support/json'
require 'active_support/concern'
require 'active_support/core_ext/hash/indifferent_access'

module ActionCable
  VERSION = '0.0.1'

  autoload :Channel, 'action_cable/channel'
  autoload :Server, 'action_cable/server'
end
