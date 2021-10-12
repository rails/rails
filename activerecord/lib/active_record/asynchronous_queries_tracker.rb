# frozen_string_literal: true

module ActiveRecord
  class AsynchronousQueriesTracker # :nodoc:
    module NullSession # :nodoc:
      class << self
        def active?
          true
        end
      end
    end

    class Session # :nodoc:
      def initialize
        @active = true
      end

      def active?
        @active
      end

      def finalize
        @active = false
      end
    end

    class << self
      def install_executor_hooks(executor = ActiveSupport::Executor)
        executor.register_hook(self)
      end

      def run
        ActiveRecord::Base.asynchronous_queries_tracker.start_session
      end

      def complete(asynchronous_queries_tracker)
        asynchronous_queries_tracker.finalize_session
      end
    end

    attr_reader :current_session

    def initialize
      @current_session = NullSession
    end

    def start_session
      @current_session = Session.new
      self
    end

    def finalize_session
      @current_session.finalize
      @current_session = NullSession
    end
  end
end
