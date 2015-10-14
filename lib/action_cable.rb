require 'eventmachine'
EventMachine.epoll  if EventMachine.epoll?
EventMachine.kqueue if EventMachine.kqueue?

require 'set'

require 'active_support'
require 'active_support/json'
require 'active_support/concern'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/module/delegation'
require 'active_support/callbacks'

require 'faye/websocket'
require 'celluloid'
require 'em-hiredis'
require 'redis'

require 'action_cable/engine' if defined?(Rails)
require 'action_cable/railtie' if defined?(Rails)

require 'action_cable/version'

module ActionCable
  autoload :Server, 'action_cable/server'
  autoload :Connection, 'action_cable/connection'
  autoload :Channel, 'action_cable/channel'
  autoload :RemoteConnections, 'action_cable/remote_connections'

  # Singleton instance of the server
  module_function def server
    @server ||= ActionCable::Server::Base.new
  end
end
