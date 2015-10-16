require "rubygems"
require "bundler"

gem 'minitest'
require "minitest/autorun"

Bundler.setup
Bundler.require :default, :test

require 'puma'
require 'mocha/mini_test'

require 'rack/mock'

require 'action_cable'
ActiveSupport.test_order = :sorted

# Require all the stubs and models
Dir[File.dirname(__FILE__) + '/stubs/*.rb'].each {|file| require file }

Celluloid.logger = Logger.new(StringIO.new)

class Faye::WebSocket
  # We don't want Faye to start the EM reactor in tests because it makes testing much harder.
  # We want to be able to start and stop EM loop in tests to make things simpler.
  def self.ensure_reactor_running
    # no-op
  end
end

class ActionCable::TestCase < ActiveSupport::TestCase
  def run_in_eventmachine
    EM.run do
      yield

      EM::Timer.new(0.1) { EM.stop }
    end
  end
end
