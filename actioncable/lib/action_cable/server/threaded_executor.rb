# frozen_string_literal: true

# :markup: markdown

module ActionCable
  module Server
    # A wrapper over ConcurrentRuby::ThreadPoolExecutor and Concurrent::TimerTask
    class ThreadedExecutor # :nodoc:
      def initialize(max_size: 10, name: "server")
        @executor = Concurrent::ThreadPoolExecutor.new(
          name: "ActionCable-#{name}",
          min_threads: 1,
          max_threads: max_size,
          max_queue: 0,
        )
      end

      def post(task = nil, &block)
        task ||= block
        @executor << task
      end

      def timer(interval, &block)
        Concurrent::TimerTask.new(execution_interval: interval, &block).tap(&:execute)
      end

      def shutdown = @executor.shutdown
    end
  end
end
