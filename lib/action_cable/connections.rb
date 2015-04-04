module ActionCable
  module Connections
    class << self
      def active
      end

      def where(identification)
      end
    end

    def disconnect
    end

    def reconnect
    end
  end
end
