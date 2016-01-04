require 'action_cable/server'
require 'eventmachine'
require 'celluloid'

EM.error_handler do |e|
  puts "Error raised inside the event loop: #{e.message}"
  puts e.backtrace.join("\n")
end

Celluloid.logger = ActionCable.server.logger
