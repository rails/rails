require 'thread'

module ActionController
  class Reloader
    @@default_lock = Mutex.new
    cattr_accessor :default_lock

    class BodyWrapper
      def initialize(body, lock)
        @body = body
        @lock = lock
      end

      def close
        @body.close if @body.respond_to?(:close)
      ensure
        Dispatcher.cleanup_application
        @lock.unlock
      end

      def method_missing(*args, &block)
        @body.send(*args, &block)
      end

      def respond_to?(symbol, include_private = false)
        symbol == :close || @body.respond_to?(symbol, include_private)
      end
    end

    def self.run(lock = @@default_lock)
      lock.lock
      begin
        Dispatcher.reload_application
        status, headers, body = yield
        # We do not want to call 'cleanup_application' in an ensure block
        # because the returned Rack response body may lazily generate its data. This
        # is for example the case if one calls
        #
        #   render :text => lambda { ... code here which refers to application models ... }
        #
        # in an ActionController.
        #
        # Instead, we will want to cleanup the application code after the request is
        # completely finished. So we wrap the body in a BodyWrapper class so that
        # when the Rack handler calls #close during the end of the request, we get to
        # run our cleanup code.
        [status, headers, BodyWrapper.new(body, lock)]
      rescue Exception
        lock.unlock
        raise
      end
    end
  end
end
