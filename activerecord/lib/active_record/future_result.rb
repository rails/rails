# frozen_string_literal: true

module ActiveRecord
  class FutureResult # :nodoc:
    Canceled = Class.new(ActiveRecordError)

    delegate :empty?, :to_a, to: :result

    def initialize(pool, *args, **kwargs)
      @mutex = Mutex.new

      @session = nil
      @pool = pool
      @args = args
      @kwargs = kwargs

      @pending = true
      @error = nil
      @result = nil
    end

    def schedule!(session)
      @session = session
      @pool.schedule_query(self)
    end

    def execute!(connection)
      execute_query(connection)
    end

    def execute_or_skip
      return unless pending?

      @pool.with_connection do |connection|
        return unless @mutex.try_lock
        begin
          if pending?
            execute_query(connection, async: true)
          end
        ensure
          @mutex.unlock
        end
      end
    end

    def result
      execute_or_wait
      if @error
        raise @error
      elsif canceled?
        raise Canceled
      else
        @result
      end
    end

    private
      def pending?
        @pending && (!@session || @session.active?)
      end

      def canceled?
        @session && !@session.active?
      end

      def execute_or_wait
        return unless pending?

        @mutex.synchronize do
          if pending?
            execute_query(@pool.connection)
          end
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
        connection.exec_query(*args, **kwargs)
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
