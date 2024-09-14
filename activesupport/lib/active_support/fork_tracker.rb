# frozen_string_literal: true

module ActiveSupport
  module ForkTracker # :nodoc:
    module CoreExt
      def _fork
        ForkTracker.before_fork_callback
        pid = super
        if pid == 0
          ForkTracker.after_fork_callback
        end
        pid
      end
    end

    @pid = Process.pid
    @before_callbacks = []
    @after_callbacks = []

    class << self
      def before_fork_callback
        @before_callbacks.each(&:call)
      end

      def after_fork_callback
        new_pid = Process.pid
        if @pid != new_pid
          @after_callbacks.each(&:call)
          @pid = new_pid
        end
      end

      def hook!
        ::Process.singleton_class.prepend(CoreExt)
      end

      def before_fork(&block)
        @before_callbacks << block
        block
      end

      def after_fork(&block)
        @after_callbacks << block
        block
      end

      def unregister_before_fork(callback)
        @before_callbacks.delete(callback)
      end

      def unregister_after_fork(callback)
        @after_callbacks.delete(callback)
      end
    end
  end
end

ActiveSupport::ForkTracker.hook!
