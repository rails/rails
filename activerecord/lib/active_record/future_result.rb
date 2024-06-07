# frozen_string_literal: true

module ActiveRecord
  class FutureResult # :nodoc:
    class Complete
      attr_reader :result
      delegate :empty?, :to_a, to: :result

      def initialize(result)
        @result = result
      end

      def pending?
        false
      end

      def canceled?
        false
      end

      def then(&block)
        Promise::Complete.new(@result.then(&block))
      end
    end

    class EventBuffer
      def initialize(future_result, instrumenter)
        @future_result = future_result
        @instrumenter = instrumenter
        @events = []
      end

      def instrument(name, payload = {}, &block)
        event = @instrumenter.new_event(name, payload)
        begin
          event.record(&block)
        ensure
          @events << event
        end
      end

      def flush
        events, @events = @events, []
        events.each do |event|
          event.payload[:lock_wait] = @future_result.lock_wait
          ActiveSupport::Notifications.publish_event(event)
        end
      end
    end

    Canceled = Class.new(ActiveRecordError)

    def self.wrap(result)
      case result
      when self, Complete
        result
      else
        Complete.new(result)
      end
    end

    delegate :empty?, :to_a, to: :result

    attr_reader :lock_wait

    def initialize(pool, *args, **kwargs)
      @mutex = Mutex.new

      @session = nil
      @pool = pool
      @args = args
      @kwargs = kwargs

      @pending = true
      @error = nil
      @result = nil
      @instrumenter = ActiveSupport::Notifications.instrumenter
      @event_buffer = nil
    end

    def then(&block)
      Promise.new(self, block)
    end

    def schedule!(session)
      @session = session
      @pool.schedule_query(self)
    end

    def execute!(connection)
      execute_query(connection)
    end

    def cancel
      @pending = false
      @error = Canceled
      self
    end

    def execute_or_skip
      return unless pending?

      @pool.with_connection do |connection|
        return unless @mutex.try_lock
        begin
          if pending?
            @event_buffer = EventBuffer.new(self, @instrumenter)
            connection.with_instrumenter(@event_buffer) do
              execute_query(connection, async: true)
            end
          end
        ensure
          @mutex.unlock
        end
      end
    end

    def result
      execute_or_wait
      @event_buffer&.flush

      if canceled?
        raise Canceled
      elsif @error
        raise @error
      else
        @result
      end
    end

    def pending?
      @pending && (!@session || @session.active?)
    end

    def canceled?
      @session && !@session.active?
    end

    private
      def execute_or_wait
        if pending?
          start = Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond)
          @mutex.synchronize do
            if pending?
              @pool.with_connection do |connection|
                execute_query(connection)
              end
            else
              @lock_wait = (Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond) - start)
            end
          end
        else
          @lock_wait = 0.0
        end
      end

      def execute_query(connection, async: false)
        @result = exec_query(connection, *@args, **@kwargs, async: async)
      rescue => error
        @error = error
      ensure
        @pending = false
      end

      def exec_query(connection, *args, **kwargs)
        connection.internal_exec_query(*args, **kwargs)
      end

      class SelectAll < FutureResult # :nodoc:
        private
          def exec_query(*, **)
            super
          rescue ::RangeError
            ActiveRecord::Result.empty
          end
      end
  end
end
