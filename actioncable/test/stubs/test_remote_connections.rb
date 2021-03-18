# frozen_string_literal: true

class TestRemoteConnections
  attr_reader :server

  def initialize(server)
    @server = server
  end

  def where(identifier)
    TestRemoteConnection.new(server, identifier)
  end

  private
    class TestRemoteConnection
      def initialize(server, ids)
        @server = server
        @ids = ids
      end

      def disconnect
        @server.broadcast "action_cable/#{@ids}", { type: "disconnect" }
      end
    end
end
