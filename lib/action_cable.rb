require 'active_support'
require 'active_support/json'
require 'active_support/concern'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/callbacks'

module ActionCable
  VERSION = '0.0.1'

  autoload :Channel, 'action_cable/channel'
  autoload :Worker, 'action_cable/worker'
  autoload :Server, 'action_cable/server'
end
