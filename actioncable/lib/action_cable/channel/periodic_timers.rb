# frozen_string_literal: true

module ActionCable
  module Channel
    module PeriodicTimers
      extend ActiveSupport::Concern

      included do
        class_attribute :periodic_timers, instance_reader: false, default: []

        after_subscribe   :start_periodic_timers
        after_unsubscribe :stop_periodic_timers
      end

      module ClassMethods
        # Periodically performs a task on the channel, like updating an online
        # user counter, polling a backend for new status messages, sending
        # regular "heartbeat" messages, or doing some internal work and giving
        # progress updates.
        #
        # Pass a method name or lambda argument or provide a block to call.
        # Specify the calling period in seconds using the <tt>every:</tt>
        # keyword argument.
        #
        #     periodically :transmit_progress, every: 5.seconds
        #
        #     periodically every: 3.minutes do
        #       transmit action: :update_count, count: current_count
        #     end
        #
        def periodically(callback_or_method_name = nil, every:, &block)
          callback =
            if block_given?
              raise ArgumentError, "Pass a block or provide a callback arg, not both" if callback_or_method_name
              block
            else
              case callback_or_method_name
              when Proc
                callback_or_method_name
              when Symbol
                -> { __send__ callback_or_method_name }
              else
                raise ArgumentError, "Expected a Symbol method name or a Proc, got #{callback_or_method_name.inspect}"
              end
            end

          unless every.kind_of?(Numeric) && every > 0
            raise ArgumentError, "Expected every: to be a positive number of seconds, got #{every.inspect}"
          end

          self.periodic_timers += [[ callback, every: every ]]
        end
      end

      private
        def active_periodic_timers
          @active_periodic_timers ||= []
        end

        def start_periodic_timers
          self.class.periodic_timers.each do |callback, options|
            active_periodic_timers << start_periodic_timer(callback, every: options.fetch(:every))
          end
        end

        def start_periodic_timer(callback, every:)
          connection.server.event_loop.timer every do
            connection.worker_pool.async_exec self, connection: connection, &callback
          end
        end

        def stop_periodic_timers
          active_periodic_timers.each { |timer| timer.shutdown }
          active_periodic_timers.clear
        end
    end
  end
end
