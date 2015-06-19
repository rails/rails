module ActionCable
  module Channel
    class Base
      include Callbacks
      include Redis

      on_subscribe   :start_periodic_timers
      on_unsubscribe :stop_periodic_timers

      on_unsubscribe :disconnect

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

        connect

        run_subscribe_callbacks
      end

      def perform_action(data)
        if authorized?
          action    = (data['action'].presence || :receive).to_sym
          signature = "#{self.class.name}##{action}: #{data}"

          if self.class.instance_methods(false).include?(action)
            logger.info "Processing #{signature}"
            public_send action, data
          else
            logger.error "Failed to process #{signature}"
          end
        else
          unauthorized
        end
      end

      def run_subscribe_callbacks
        self.class.on_subscribe_callbacks.each do |callback|
          send(callback)
        end
      end
      def perform_disconnection
        run_unsubscribe_callbacks
        logger.info "#{self.class.name} disconnected"
      end

      protected
        # Override in subclasses
        def authorized?
          true
        end

        def unauthorized
          logger.error "Unauthorized access to #{self.class.name}"
        end

        def connect
          # Override in subclasses
        end

        def disconnect
          # Override in subclasses
        end

        def broadcast(data)
          if authorized?
            connection.broadcast({ identifier: @channel_identifier, message: data }.to_json)
          else
            unauthorized
          end
        end

      private
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
          @_active_periodic_timers.each {|t| t.cancel }
        end

        def worker_pool
          connection.worker_pool
        end
    end
  end
end