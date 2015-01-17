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

        def find_name
          @name ||= channel_name || to_s.demodulize.underscore
        end
      end

      def initialize(connection, channel_identifier, params = {})
        @connection = connection
        @channel_identifier = channel_identifier
        @_active_periodic_timers = []
        @params = params

        connect

        subscribe
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
        def connect
          # Override in subclasses
        end

        def broadcast(data)
          @connection.broadcast({ identifier: @channel_identifier, message: data }.to_json)
        end

        def start_periodic_timers
          self.class.periodic_timers.each do |callback, options|
            @_active_periodic_timers << EventMachine::PeriodicTimer.new(options[:every]) do
              callback.respond_to?(:call) ? instance_exec(&callback) : send(callback)
            end
          end
        end

        def stop_periodic_timers
          @_active_periodic_timers.each {|t| t.cancel }
        end
    end

  end
end