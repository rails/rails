require 'support/env_helpers'

class TestConnection < ActionCable::Connection::Base
  include EnvHelpers
  attr_reader :connected, :errors, :message_buffer, :transmissions, :websocket

  def initialize(server = TestServer.new, env = rack_hijack_env, *)
    super
    @errors = []
    @transmissions = []
  end

  def connect
    @connected = true
  end

  def disconnect
    @connected = false
  end

  def last_transmission
    @coder.decode(@transmissions.last) if @transmissions.any?
  end

  def on_error(error)
    @errors << error
  end

  def send_async(method, *args)
    send method, *args
  end

  def transmit(cable_message)
    super
    @transmissions << encode(cable_message)
  end
end
