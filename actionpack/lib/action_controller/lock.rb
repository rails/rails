module ActionController
  class Lock
    def initialize(app)
      @app = app
      @lock = Mutex.new
    end

    def call(env)
      old_multithread = env["rack.multithread"]
      env["rack.multithread"] = false
      response = @lock.synchronize do
        @app.call(env)
      end
      env["rack.multithread"] = old_multithread
      response
    end
  end
end
