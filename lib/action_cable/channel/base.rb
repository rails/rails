module ActionCable
  module Channel

    class Base
      include Callbacks

      on_subscribe :start_periodic_timers
      on_unsubscribe :stop_periodic_timers

      attr_reader :params

      class_attribute :channel_name

      class << self
        def matches?(identifier)
          raise "Please implement #{name}#matches? method"
        end
      end

      def initialize(connection, channel_identifier, params = {})
        @connection = connection
        @channel_identifier = channel_identifier
        @_active_periodic_timers = []
        @params = params

        setup
      end

      def receive(data)
        raise "Not implemented"
      end

      def subscribe
        self.class.on_subscribe_callbacks.each do |callback|
          EM.next_tick { send(callback) }
        end
      end

      def unsubscribe
        self.class.on_unsubscribe.each do |callback|
          EM.next_tick { send(callback) }
        end
      end

      protected
        def setup
          # Override in subclasses
        end

        def broadcast(data)
          @connection.broadcast(data.merge(identifier: @channel_identifier).to_json)
        end

        def start_periodic_timers
          self.class.periodic_timers.each do |method, options|
            @_active_periodic_timers << EventMachine::PeriodicTimer.new(options[:every]) { send(method) }
          end
        end

        def stop_periodic_timers
          @_active_periodic_timers.each {|t| t.cancel }
        end
    end

  end
end