module ActionCable
  module Channel
    class Base
      include Callbacks
      include Redis

      on_subscribe   :start_periodic_timers
      on_unsubscribe :stop_periodic_timers

      attr_reader :params, :connection
      delegate :logger, to: :connection

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

        perform_connection
      end

      def perform_connection
        logger.info "#{channel_name} connecting"
        connect
        run_subscribe_callbacks
      end

      def perform_action(data)
        if authorized?
          action = extract_action(data)

          if performable_action?(action)
            logger.info action_signature(action, data)
            public_send action, data
          else
            logger.error "Unable to process #{action_signature(action, data)}"
          end
        else
          unauthorized
        end
      end

      def perform_disconnection
        disconnect
        run_unsubscribe_callbacks
        logger.info "#{channel_name} disconnected"
      end


      protected
        # Override in subclasses
        def authorized?
          true
        end

        def unauthorized
          logger.error "#{channel_name}: Unauthorized access"
        end


        def connect
          # Override in subclasses
        end

        def disconnect
          # Override in subclasses
        end


        def transmit(data, via: nil)
          if authorized?
            logger.info "#{channel_name} transmitting #{data.inspect}".tap { |m| m << " (via #{via})" if via }
            connection.transmit({ identifier: @channel_identifier, message: data }.to_json)
          else
            unauthorized
          end
        end


        def channel_name
          self.class.name
        end

      private
        def extract_action(data)
          (data['action'].presence || :receive).to_sym
        end

        def performable_action?(action)
          self.class.instance_methods(false).include?(action)
        end

        def action_signature(action, data)
          "#{channel_name}##{action}".tap do |signature|
            if (arguments = data.except('action')).any?
              signature << "(#{arguments.inspect})"
            end
          end
        end


        def run_subscribe_callbacks
          self.class.on_subscribe_callbacks.each { |callback| send(callback) }
        end

        def run_unsubscribe_callbacks
          self.class.on_unsubscribe_callbacks.each { |callback| send(callback) }
        end


        def start_periodic_timers
          self.class.periodic_timers.each do |callback, options|
            @_active_periodic_timers << EventMachine::PeriodicTimer.new(options[:every]) do
              worker_pool.async.run_periodic_timer(self, callback)
            end
          end
        end

        def stop_periodic_timers
          @_active_periodic_timers.each { |timer| timer.cancel }
        end


        def worker_pool
          connection.worker_pool
        end
    end
  end
end