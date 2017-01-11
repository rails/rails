require "stubs/user"

class TestClient < ActionCable::Client::Base
  attr_reader :connected

  identified_by :current_user

  def initialize(connection, user: nil, **params)
    super(connection, **params)
    @current_user = user
  end

  def connect
    @connected = true
  end

  def disconnect
    @connected = false
  end
end
