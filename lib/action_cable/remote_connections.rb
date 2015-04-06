module ActionCable
  class RemoteConnections
    attr_reader :server

    def initialize(server)
      @server = server
    end

    def where(identifier)
      RemoteConnection.new(server, identifier)
    end
  end
end
