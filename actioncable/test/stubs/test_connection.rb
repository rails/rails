require "stubs/user"

class TestConnection < ActionCable::Connection::Base
  attr_reader :connected

  identified_by :current_user

  def initialize(socket, user: nil, **params)
    super(socket, **params)
    @current_user = user
  end

  def connect
    @connected = true
  end

  def disconnect
    @connected = false
  end
end
