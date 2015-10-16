require 'active_support'
require 'active_support/rails'
require 'action_cable/version'

module ActionCable
  extend ActiveSupport::Autoload

  # Singleton instance of the server
  module_function def server
    @server ||= ActionCable::Server::Base.new
  end

  eager_autoload do
    autoload :Server
    autoload :Connection
    autoload :Channel
    autoload :RemoteConnections
  end
end

require 'action_cable/engine' if defined?(Rails)
