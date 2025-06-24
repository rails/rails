# frozen_string_literal: true

module ActiveSupport
  module ForkTracker # :nodoc:
    module CoreExt
      def _fork
        pid = super
        if pid == 0
          ForkTracker.after_fork_callback
        end
        pid
      end
    end

    @pid = Process.pid
    @callbacks = []

    class << self
      def after_fork_callback
        new_pid = Process.pid
        if @pid != new_pid
          @callbacks.each(&:call)
          @pid = new_pid
        end
      end

      def hook!
        ::Process.singleton_class.prepend(CoreExt)
      end

      def after_fork(&block)
        @callbacks << block
        block
      end

      def unregister(callback)
        @callbacks.delete(callback)
      end
    end
  end
end

ActiveSupport::ForkTracker.hook!
