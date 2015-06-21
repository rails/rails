module ActionCable
  module Connection
    class Heartbeat
      BEAT_INTERVAL = 3
      
      def initialize(connection)
        @connection = connection
      end

      def start
        beat
        @timer = EventMachine.add_periodic_timer(BEAT_INTERVAL) { beat }
      end

      def stop
        EventMachine.cancel_timer(@timer) if @timer
      end

      private
        attr_reader :connection
        
        def beat
          connection.transmit({ identifier: '_ping', message: Time.now.to_i }.to_json)
        end
    end
  end
end