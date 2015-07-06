module ActionCable
  module Channel
    module PeriodicTimers
      extend ActiveSupport::Concern
      
      included do
        class_attribute :periodic_timers, instance_reader: false
        self.periodic_timers = []

        on_subscribe   :start_periodic_timers
        on_unsubscribe :stop_periodic_timers
      end

      module ClassMethods
        def periodically(callback, every:)
          self.periodic_timers += [ [ callback, every: every ] ]
        end
      end

      private
        def active_periodic_timers
          @active_periodic_timers ||= []
        end

        def start_periodic_timers
          self.class.periodic_timers.each do |callback, options|
            active_periodic_timers << EventMachine::PeriodicTimer.new(options[:every]) do
              worker_pool.async.run_periodic_timer(self, callback)
            end
          end
        end

        def stop_periodic_timers
          active_periodic_timers.each { |timer| timer.cancel }
        end
    end
  end
end