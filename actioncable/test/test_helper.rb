require File.expand_path('../../../load_paths', __FILE__)

require 'action_cable'
require 'active_support/testing/autorun'


require 'puma'
require 'em-hiredis'

require 'mocha/setup'

require 'rack/mock'

# Require all the stubs and models
Dir[File.dirname(__FILE__) + '/stubs/*.rb'].each {|file| require file }

$CELLULOID_DEBUG = false
$CELLULOID_TEST  = false
require 'celluloid'
Celluloid.logger = Logger.new(StringIO.new)

require 'faye/websocket'
class << Faye::WebSocket
  remove_method :ensure_reactor_running

  # We don't want Faye to start the EM reactor in tests because it makes testing much harder.
  # We want to be able to start and stop EM loop in tests to make things simpler.
  def ensure_reactor_running
    # no-op
  end
end

class ActionCable::TestCase < ActiveSupport::TestCase
  def run_in_eventmachine
    EM.run do
      yield

      EM.run_deferred_callbacks
      EM.stop
    end
  end
end
